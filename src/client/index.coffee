$(document).ready ->

  #
  # CSInterface Work
  #
  csInterface = new CSInterface
  csInterface.requestOpenExtension 'com.my.localserver', ''
  hook = (hookString, callback = null) ->
    csInterface.evalScript hookString, callback

  # Let Keystrokes through
  # OSVersion = csInterface.getOSInformation()
  # if OSVersion.indexOf("Windows") >= 0
  #   csInterface.registerKeyEventsInterest keyEventsInterest.win
  # else if OSVersion.indexOf("Mac") >= 0
  #   csInterface.registerKeyEventsInterest keyEventsInterest.mac

  # csInterface.addEventListener "documentAfterSave", (event) ->
  #   obj = event.data
  #   console.log(event)

  #
  # Load NF Libs
  #

  hook "var i, len, nfInclude, path, includePaths;
        var includePaths = $.includePath.split(';');
        for (i = 0, len = includePaths.length; i < len; i++) {
          path = includePaths[i];
          if (path.indexOf('avo_toolkit') >= 0) {
            nfInclude = path;
          }
        }
        $.evalFile(nfInclude + '/../lib/nf_tools/build/runtimeLibraries.jsx');"

  #
  # Global Vars
  #
  latestAnnotationData = {}
  smartTimer = null
  POLLING_INTERVAL = 1000
  POLLING_TIMEOUT = 25000 #25s
  MAX_POLLING_ITERATIONS = 3600 # 1hr
  NFClass =
    Comp: "NFComp"
    PartComp: "NFPartComp"
    PageComp: "NFPageComp"
    Layer: "NFLayer"
    PageLayer: "NFPageLayer"
    CitationLayer: "NFCitationLayer"
    GaussyLayer: "NFGaussyLayer"
    EmphasisLayer: "NFEmphasisLayer"
    HighlightLayer: "NFHighlightLayer"
    HighlightControlLayer: "NFHighlightControlLayer"
    ShapeLayer: "NFShapeLayer"
    ReferencePageLayer: "NFReferencePageLayer"

  # Debug Vars
  timerCounter = 0

  # Default Settings
  defaultSettings =
    edgePadding : 80
    bottomPadding : 150
    maskExpansion: 26

    transforms:
      page:
        scale:
          large: 40
          small: 17
        position:
          large: [960, 1228.2]
          small: [1507, 567]

    constraints:
      fst:
        width: 80
        top: 18

    expose:
      maxScale: 100
      fillPercentage: 90

    durations:
      pageShrink: 1.2
      pageGrow: 1.2
      refTransition: 0.6#1
      expandTransition: 0.7#1
      fadeIn: 0.5#0.7
      slideIn: 1.5#2
      slideOut: 0.8#2
      multiEndOffset: 0.3

  #
  # Helper Functions
  #
  rgbToHex = (r, g, b) ->
    componentToHex = (c) ->
      hex = c.toString(16)
      if hex.length == 1 then '0' + hex else hex

    if r.length is 3
      b = r[2]
      g = r[1]
      r = r[0]
    '#' + componentToHex(r) + componentToHex(g) + componentToHex(b)
  rgbaToFloatRGB = (arr) ->
    return [arr[0]/255, arr[1]/255, arr[2]/255]
  rgbToRGBA255 = (arr) ->
    return [Math.round(arr[0]*255), Math.round(arr[1]*255), Math.round(arr[2]*255)]

  displayError = (message) ->
    $bar = $('#error-bar')
    $bar.text "ERROR: #{message}"
    $bar.show()

  rectHash = (rect) ->
    return  [Math.floor(rect.height * 31 + rect.width),  Math.floor(rect.top * 31 + rect.left)]

  $('#error-bar').click ->
    $(this).hide()

  currentSettings = {}
  populateSettingsPanelFromFile = ->
    hook "editDefaultsFile()", (res) ->
      if res is ""
        hook "editDefaultsFile(#{JSON.stringify(defaultSettings)})"
        settingsContent = defaultSettings
      else settingsContent = JSON.parse res

      addSettingsItem = (name, value, destination) ->
        if typeof value is 'object' and value isnt null
          listItem = $("<li></li>")
          destination.append listItem
          dataVal =
            name: name
            value: value
          listItem.data(dataVal)
          subList = $("<ul><p>#{name}</p></ul>")
          listItem.append subList
          for subKey, subVal of value
            addSettingsItem subKey, subVal, subList
        else
          textBox = $("<input type='text' placeholder='#{name}' value='#{value}'></input><label>#{name}</label>")
          newSettingsItem = $("<li></li>").append textBox
          dataVal =
            name: name
            value: value
          newSettingsItem.data(dataVal)
          destination.append newSettingsItem

      $("#settings-options").html("")
      mainList = $("<ul></ul>")
      mainSettingsList = $("#settings-options").append mainList

      for k,v of settingsContent
        addSettingsItem k, v, mainList
      currentSettings = settingsContent

  getPageAnnotations = ->
    disp = $("#annotation-display")
    annotationDate = new Date()
    console.log "getPageAnnotations()"
    hook "app.project", (res) ->
      if res?
        hook "getActivePageFile()", (result) ->
          console.log "annotation hook returned - #{new Date() - annotationDate}ms"
          console.log result
          if result isnt "null" and result isnt "" and result isnt null
            url = 'http://localhost:3200/annotationData'
            $.ajax
              type: 'GET'
              url: url
              data: filepath: result
              success: (response) ->
                # Don't bother doing anything if there's no change
                if JSON.stringify(response) is JSON.stringify(latestAnnotationData)
                  # console.log "no change to data"
                else
                  # console.log "data changed - updating"
                  # console.log response
                  latestAnnotationData = response
                  disp.empty()
                  if response.length is 0
                    disp.append "<p class='no-annotations-found'>No annotations found in this PDF</p>"
                  else
                    console.log response
                    for annotation, i in response
                      annotHash = rectHash annotation.rect
                      matchClass = ""

                      existingHighlights = $('body').data().highlightLayers
                      for highlightLayer, j in existingHighlights
                        if highlightLayer.rectHash?
                          if highlightLayer.rectHash[0] is annotHash[0] and highlightLayer.rectHash[1] is annotHash[1]
                            matchClass = "match-#{highlightLayer.index} matched"

                      dispID = "annotation-#{annotHash[0]}-#{annotHash[1]}"
                      colorClassName = annotation.colorName.replace(/\s+/g, '-').toLowerCase()
                      disp.append "<li id='#{dispID}' class='annotation-item #{colorClassName} #{matchClass}'></li>"
                      dispElement = $("##{dispID}")
                      dispElement.append "<div class='clean-name'>#{annotation.cleanName}</div>
                                          <div class='highlight-text'>#{annotation.text}</div>"
                      annotation.rectHash = annotHash
                      annotationDataString = JSON.stringify annotation
                      dispElement.data annotationDataString

                      if matchClass.indexOf('matched') >= 0
                        dispElement.append "<div class='action-buttons'>
                                              <div class='button-group'>
                                                <div class='delete'></div>
                                              </div>
                                              <div class='button-group'>
                                                <div class='add-line'></div>
                                                <div class='remove-line'></div>
                                              </div>
                                              <div class='button-group'>
                                                <div class='split-highlight'></div>
                                              </div>
                                              <div class='button-group'>
                                                <div class='unlink'></div>
                                              </div>
                                            </div>"
                        dispElement.find('.delete').click {}, (e) ->
                          classNames = $(this).parent().parent().parent().attr('class')
                          theExp = /match-(.*?)[\s]/g
                          theIdx = parseInt(theExp.exec(classNames)[1])
                          hook "deleteHighlightAtIndex('#{theIdx}')"
                        dispElement.find('.add-line').click {param: annotationDataString}, (e) ->
                          classNames = $(this).parent().parent().parent().attr('class')
                          theExp = /match-(.*?)[\s]/g
                          theIdx = parseInt(theExp.exec(classNames)[1])
                          hook "changeLineCountForHighlightAtIndex('#{theIdx}', '1')"
                        dispElement.find('.remove-line').click {param: annotationDataString}, (e) ->
                          classNames = $(this).parent().parent().parent().attr('class')
                          theExp = /match-(.*?)[\s]/g
                          theIdx = parseInt(theExp.exec(classNames)[1])
                          hook "changeLineCountForHighlightAtIndex('#{theIdx}', '-1')"
                        dispElement.find('.unlink').click {}, (e) ->
                          classNames = $(this).parent().parent().parent().attr('class')
                          theExp = /match-(.*?)[\s]/g
                          theIdx = parseInt(theExp.exec(classNames)[1])
                          hook "unlinkHighlightAtIndex('#{theIdx}')"
                        dispElement.find('.split-highlight').click {}, (e) ->
                          classNames = $(this).parent().parent().parent().attr('class')
                          theExp = /match-(.*?)[\s]/g
                          theIdx = parseInt(theExp.exec(classNames)[1])
                          hook "splitHighlightAtIndex('#{theIdx}')"
                      else
                        dispElement.append "<div class='action-buttons'>
                                              <div class='button-group'>
                                                <div class='add-magic'></div>
                                              </div>
                                              <div class='button-group'>
                                                <div class='add-manual'></div>
                                              </div>
                                              <div class='button-group'>
                                                <div class='link-existing'></div>
                                              </div>
                                            </div>"

                        dispElement.find('.add-magic').click {param: annotationDataString}, (e) ->
                          hook "createHighlightFromAnnotation('#{e.data.param}')"
                        dispElement.find('.add-manual').click {param: annotationDataString}, (e) ->
                          hook "prompt('How many lines?')", (res) ->
                            param = JSON.parse e.data.param
                            lineCount = parseInt(res)
                            if isNaN(lineCount)
                              alert "Error:\nThe value entered ('#{res}') is not a valid integer."
                            else
                              param.lineCount = lineCount
                              hook "createHighlightFromAnnotation('#{JSON.stringify param}')"
                        dispElement.find('.link-existing').click {param: annotationDataString}, (e) ->
                          hook "linkHighlightToSelectedLayer('#{e.data.param}')"


              error: (jqXHR, textStatus, errorThrown) ->
                console.log "Error: #{errorThrown}, #{jqXHR.responseJSON}"
                disp.empty()
                disp.append "<p class='error-thrown'>The PDF Server returned an error. 🤷Talk to Jesse...</p>"
                latestAnnotationData = {}
          else
            disp.empty()
            disp.append "<p class='no-active-page'>No active page</p>"
            latestAnnotationData = {}
      else
        disp.empty()
        disp.append "<p class='no-active-project'>No active project</p>"
        latestAnnotationData = {}

  compLayerType = ""
  timerCounter = 0
  checkForUpdates = ->
    if timerCounter >= MAX_POLLING_ITERATIONS
      console.log "threshold reached - stopping smart updates"
      timerCounter = 0
      $('#smart-toggle').click()
    else
      getPollingData()

  getPollingData = ->
    console.log "polling (#{if smartTimer? then timerCounter else "one-time"})..."
    startInterval = new Date()
    hook "getPollingData()", (res) ->
      requestTime = new Date() - startInterval
      console.log "polling data returned (#{if smartTimer? then timerCounter else "one-time"}) - #{requestTime}ms"

      if requestTime > POLLING_TIMEOUT and smartTimer?
        timerCounter = 0
        $('#smart-toggle').click()
        return console.log "turning off smart updates - request took too long"

      if not res? or res.length is 0 or res.indexOf("Error") is 0
        displayError "got nothing back from polling hook!"
        $("body").removeClass()
      else
        if res isnt "undefined"
          # console.log res
          data = JSON.parse res
          if compLayerType isnt data.bodyClass
            compLayerType = data.bodyClass
            $("body").removeClass()
            $("body").addClass(compLayerType)
          $("body").data data
          timerCounter++
          if compLayerType.indexOf(NFClass.PageComp) >= 0
            getPageAnnotations()
          if compLayerType.indexOf(NFClass.EmphasisLayer) >= 0
            loadEmphasisPane()
          if compLayerType.indexOf(NFClass.PartComp) >= 0
            loadLayoutPane()

  #
  # Bindings
  #
  $('#reload-button').click ->
    clearInterval smartTimer if smartTimer?
    hook "var i, len, nfInclude, path, includePaths;
          var includePaths = $.includePath.split(';');
          for (i = 0, len = includePaths.length; i < len; i++) {
            path = includePaths[i];
            if (path.indexOf('jl_pdf_manager') >= 0) {
              nfInclude = path;
            }
          }
          $.evalFile(nfInclude + '/../host/hooks.jsx');"
    # hook "NFTools.evalFile('hooks.jsx')"
    window.location.reload true

  $('#smart-toggle').click ->
    if smartTimer?
      $("#smart-toggle").removeClass("running")
      $('#one-page-annotations').removeClass("disabled")
      clearInterval smartTimer
      smartTimer = null
    else
      $("#smart-toggle").addClass("running")
      $('#one-page-annotations').addClass("disabled")
      smartTimer = setInterval checkForUpdates, POLLING_INTERVAL
  # Default the timer to on
  $('#smart-toggle').click()

  $('#single-fetch').click ->
    getPollingData()
  $('#convert-shape').click ->
    hook "convertShapeToHighlight()"
  $('#classic-highlight').click ->
    hook "NFTools.evalFile('nf_SetupHighlightLayer.jsx')"
  $('#tool-panel').click ->
    $('.tab').removeClass "active"
    $('.tab.tool-panel').addClass "active"
  $('#settings-tab-button').click ->
    $('.tab').removeClass "active"
    $('.tab.settings').addClass "active"
    populateSettingsPanelFromFile()

  $('#save-settings').click ->
    # Build a new object
    getElementsInUL = (ul) ->
      retObj = {}
      ul.children("li").each (i) ->
        subList = $(@).children("ul")
        if subList.length
          if $(@).data().value instanceof Array
            assemblyArr = []
            subList.children("li").each (i) ->
              assemblyArr.push parseFloat($(@).children("input").val())
            retObj[$(@).data().name] = assemblyArr
          else
            retObj[$(@).data().name] = getElementsInUL(subList)
        else
          retObj[$(@).data().name] = parseFloat($(@).children("input").val())
      return retObj

    newSettingsObj = getElementsInUL($("#settings-options > ul"))
    hook "editDefaultsFile(#{JSON.stringify(newSettingsObj)})"
    currentSettings = newSettingsObj

  $('#reset-changes').click ->
    populateSettingsPanelFromFile()
  $('#restore-all-settings').click ->
    hook "editDefaultsFile('')"
    populateSettingsPanelFromFile()

  $('#toggle-guides').click ->
    hook "toggleGuideLayers()"
  $('#shy-show-all').click ->
    hook "focusOn('all')"
  $('#shy-focus-pdf').click ->
    hook "focusOn('pdf')"
  $('#shy-focus-active').click ->
    hook "focusOn('active')"


  $("#out-transition .nf-fade").click ->
    hook "transitionFadeOut()"
  $("#in-transition .nf-fade").click ->
    hook "transitionFadeIn()"
  $("#out-transition .nf-slide").click ->
    hook "transitionSlideOut()"
  $("#in-transition .nf-slide").click ->
    hook "transitionSlideIn()"
  $("#out-transition .nf-fade-scale").click ->
    hook "transitionFadeScaleOut()"
  $("#in-transition .nf-fade-scale").click ->
    hook "transitionFadeScaleIn()"
  $("#out-transition .clear").click ->
    hook "transitionClearOut()"
  $("#in-transition .clear").click ->
    hook "transitionClearIn()"


  $("button.emphasizer-button").click ->
    hook "emphasisLayerSelected()", (res) ->
      if res is "true"
        hook "NFTools.evalFile('nf_Emphasizer.jsx')"
      else hook "makeEmphasisLayer()"

  $("button.gaussy-button").click ->
    hook "addGaussy()", (res) ->
      return null

  $("button.browser-button").click ->
    hook "addBrowser()", (res) ->
      return null

  $("button.blend-button").click ->
    $('#blend-menu').toggle()
  $('#blend-screen-button').click ->
    $('#blend-menu').toggle()
    hook "setBlendingMode('screen')"
  $('#blend-normal-button').click ->
    $('#blend-menu').toggle()
    hook "setBlendingMode('normal')"
  $('#blend-multiply-button').click ->
    $('#blend-menu').toggle()
    hook "setBlendingMode('multiply')"
  $('#blend-overlay-button').click ->
    $('#blend-menu').toggle()
    hook "setBlendingMode('overlay')"


  # # print all events on an element
  # getAllEvents = (element) ->
  #   result = []
  #   for key of element
  #     if key.indexOf('on') == 0
  #       result.push key.slice(2)
  #   result.join ' '
  #
  # el = $newShapeItem
  # el.bind getAllEvents(el[0]), (e) ->
  #   console.log e

  isChangingValue = no
  $('#emphasizer-panel .slider-container input').on "pointerdown", ->
    isChangingValue = yes

  $('#emphasizer-panel .slider-container input').change ->
    isChangingValue = no
    $(this).siblings(".value").text($(this).val())

    if $(this).is("#thickness-slider")
      thicknessValue = $(this).val()
      emphParams =
        name: $('#emphasis-list li.active').data().name
        thickness: thicknessValue
      hook "setEmphasisProperties('#{JSON.stringify emphParams}')"


  $('#emphasis-list').on 'click', 'li', ->
    $('#emphasis-list li.active').removeClass('active')
    $(this).addClass('active')
    loadEmphasisPane()

  $('#emphasizer-panel button.apply-to-all').click ->
    effects = $('body').data().effects
    for item in effects
      emphParams =
        name: item.name
        color: $('#emphasis-list li.active').data().properties.Color.value
      hook "setEmphasisProperties('#{JSON.stringify emphParams}')"

    loadEmphasisPane()

  loadEmphasisPane = ->
    data = $('body').data()
    sameLayer = no

    # Title
    $title = $("#emphasis-title")
    oldTitle = $title.text()
    if oldTitle is data.selectedLayers[0]
      sameLayer = yes
    else
      $title.text data.selectedLayers[0]

    # List
    $list = $('#emphasis-list')
    if sameLayer
      $activeItem = $list.find('li.active')
      if $activeItem? and $activeItem.data()?
        activeItemName = $activeItem.data().name
      else
        activeItemName = null
    $list.empty()
    if data.effects.length isnt 0
      # list.append "<li class='all'>All</li>"
      for effect, i in data.effects
        newItem = $("<li>#{effect.name}</li>").appendTo $list
        newItem.data effect

        if (i is 0 and not activeItemName?) or (effect.name is activeItemName)
          newItem.addClass("active")
        bullet = $("<span class='bullet'>&#9632;</span>").prependTo newItem
        bulletColor = rgbToHex rgbToRGBA255(effect.properties.Color.value.slice(0,3))
        bullet.css "color", bulletColor

    else
      $list.append "<li class='none'>No Emphasizers</li>"

    if data.effects.length isnt 0
      # Color
      dataColor = $list.find('li.active').data().properties.Color.value
      rgba225Color = rgbToRGBA255(dataColor)
      rgbString = "rgb(#{rgba225Color[0]}, #{rgba225Color[1]}, #{rgba225Color[2]})"
      unless pickerActive
        empColorPickButton.css
          'background-color': rgbString

      # Thickness
      unless isChangingValue
        dataThickness = $list.find('li.active').data().properties.Thickness.value
        $thicknessSlider = $('#thickness-slider')
        $thicknessSlider.val dataThickness
        $thicknessSlider.siblings(".value").text dataThickness


  empColorPickButton = $('#emphasizer-panel .color-field')
  colorPicker = new Picker empColorPickButton[0]
  pickerActive = false
  # console.log "color" + parent.style.backgroundColor
  colorPicker.setOptions
    popup: "top"
    alpha: false
    color: empColorPickButton.css "background-color"
    onOpen: (color) ->
      pickerActive = yes
      # Trust the button
      colorPicker.setColor empColorPickButton.css('background-color')
    onChange: (color) ->
      # Set the picker button's color
      empColorPickButton.css
        'background-color': color.rgbaString
    onDone: (color) ->
      # Set the picker button's color
      empColorPickButton.css
        'background-color': color.rgbaString
      # Set the actual cylon color
      emphParams =
        name: $('#emphasis-list li.active').data().name
        color: rgbaToFloatRGB(color.rgba)
      hook "setEmphasisProperties('#{JSON.stringify emphParams}')"
    onClose: (color) ->
      # Any data changes should have been made by now, so let's do the thing
      pickerActive = no
      loadEmphasisPane()

  loadToolTab = ->
    $tools = $("#tool-panel-tools")
    toolRegistry = null
    hook "JSON.stringify(toolRegistry)", (res) ->
      if res is ""
        $('#tool-panel').addClass('disabled')
      else
        $('#tool-panel').removeClass('disabled')
        toolRegistry = JSON.parse res
        for key of toolRegistry
          category = toolRegistry[key]
          $("<h3>#{category.name}</h3>").appendTo $tools
          $newCategoryList = $("<ul class='category-list'></ul>").appendTo $tools

          for toolKey of category.tools
            thisTool = category.tools[toolKey]
            $newListItem = $("<li class='tool-item'>#{thisTool.name}</li>").appendTo $newCategoryList
            $newListItem.data
              key: toolKey

  loadToolTab()
  populateSettingsPanelFromFile()

  $('#close-tool-panel').click (e) ->
    $('.tab').removeClass('active')
    $('.tab.main').addClass('active')
  $('#close-settings-panel').click (e) ->
    $('.tab').removeClass('active')
    $('.tab.main').addClass('active')

  $('#run-tool').click (e) ->
    hook "runTool('#{$("#tool-panel-tools li.active").data().key}')"
    $("#tool-panel-tools li.active").removeClass "active"

  $("#tool-panel-tools").on 'click', 'li', (e) ->
    event.stopPropagation()
    $("#tool-panel-tools li").removeClass "active"
    $(this).addClass "active"

  $("#tool-panel-tools").on 'dblclick', 'li', (e) ->
    event.stopPropagation()
    $('#run-tool').click()

  loadLayoutPane = (refreshTree = no) ->
    data = $("body").data()

    $itemName = $('#layout-panel .active-item .item-name')
    if data.selectedLayers.length is 0
      $itemName.text "No layer selected"
    else if data.selectedLayers.length is 1
      singleLayer = data.selectedLayers[0]
      $itemName.text singleLayer.name
    else if data.selectedLayers.length > 1
      $itemName.text "Multiple layers selected"

    $('#layout-panel .active-item .item-control button').addClass 'disabled'

    $('#layout-panel .active-item button.refresh-tree').removeClass 'disabled'

    if singleLayer?.class is NFClass.PageLayer
      $('#layout-panel .active-item button.shrink-page').removeClass 'disabled'
      $('#layout-panel .active-item button.grow-page').removeClass 'disabled'
      $('#layout-panel .active-item button.end-element').removeClass 'disabled'
    if singleLayer?.class is NFClass.ReferencePageLayer or data.selectedLayers.length > 1
      $('#layout-panel .active-item button.re-anchor').removeClass 'disabled'
      $('#layout-panel .active-item button.end-element').removeClass 'disabled'
    if singleLayer?.class is NFClass.Layer or singleLayer?.class is NFClass.GaussyLayer
      $('#layout-panel .active-item button.end-element').removeClass 'disabled'

    # Load Selector
    $list = $("#selector-list")
    if $list.children().length is 0 or refreshTree is yes
      $list.empty()
      hook "getFullPDFTree()", (res) ->
        # console.log res
        if typeof res is "string"
          if res.indexOf("Error") > -1
            hook "alert('Error getting PDF tree:#{res}')"
            $('#smart-toggle').click() if smartTimer?
        selectorData = JSON.parse res
        # console.log selectorData
        for pdfItem in selectorData.pdfs
          $newPDFItem = $("<li class='pdf-item'><span>#{pdfItem.name.slice(4)}</span></li>").appendTo $list
          $newPDFItem.data pdfItem
          $pageList = $("<ul></ul>").appendTo $newPDFItem
          for pageItem in pdfItem.pages
            $newPageItem = $("<li class='page-item'><span>#{pageItem.name.substring(pageItem.name.lastIndexOf('pg') + 2, pageItem.name.lastIndexOf(' '))}</span></li>").appendTo $pageList
            $newPageItem.data pageItem
            if pageItem.shapes.length > 0
              $shapeList = $("<ul></ul>").appendTo $newPageItem
              for shapeItem in pageItem.shapes

                $newShapeItem = $("<li class='shape-item'><span>#{shapeItem.name}</span></li>").appendTo $shapeList
                $newShapeItem.data shapeItem

  $('#selector-list').on 'click', 'li', (event) ->
    event.stopPropagation()

    if $(this).hasClass('collapsed')
      $(this).removeClass 'collapsed'
    else $(this).addClass 'collapsed'

    unless $(this).hasClass('active')
      $('#selector-list li').removeClass('active')
      targetData = $(this).data()
      targetClass = targetData.class

      $('#layout-panel .selector-buttons button').addClass('disabled')
      if targetClass is NFClass.PageComp
        $('#layout-panel .fullscreen-title').removeClass('disabled')
        $('#layout-panel .add-small').removeClass('disabled')
        if targetData.pdfNumber is $('body').data().activePDF and targetData.pageNumber isnt $('body').data().activePage.pageNumber
          $('#layout-panel .switch-to-page').removeClass('disabled')

      if targetClass is NFClass.ShapeLayer or targetClass is NFClass.HighlightLayer
        $('#layout-panel .expose').removeClass('disabled')
        $('#layout-panel .bubble-up').removeClass('disabled')
        if targetData.name.toLowerCase().indexOf('expand') >= 0
          $('#layout-panel .expand').removeClass('disabled')

      $(this).addClass 'active'

  $('#selector-list').on 'dblclick', 'li.page-item', (e) ->
    targetData = $(this).data()
    hook "openComp(#{JSON.stringify targetData})"

  $('#layout-panel .refresh-tree').click (e) ->
    unless $(this).hasClass 'disabled'
      loadLayoutPane yes

  $('#layout-panel .shrink-page').click (e) ->
    unless $(this).hasClass 'disabled'
      model =
        target: $('body').data().selectedLayers
        command: "shrink-page"
        settings: currentSettings
      hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .grow-page').click (e) ->
    unless $(this).hasClass 'disabled'
      model =
        target: $('body').data().selectedLayers
        command: "fullscreen-title"
        settings: currentSettings
      hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .re-anchor').click (e) ->
    unless $(this).hasClass 'disabled'
      model =
        target: $('body').data().selectedLayers
        command: "anchor"
        settings: currentSettings
      hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .end-element').click (e) ->
    unless $(this).hasClass 'disabled'
      model =
        target: $('body').data().selectedLayers
        command: "end-element"
        settings: currentSettings
      hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .fullscreen-title').click (e) ->
    unless $(this).hasClass 'disabled'
      $activeItem = $('#selector-list li.active')
      if $activeItem?.data().class is NFClass.PageComp
        model =
          target: $activeItem.data()
          command: "fullscreen-title"
          settings: currentSettings
        hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .add-small').click (e) ->
    unless $(this).hasClass 'disabled'
      $activeItem = $('#selector-list li.active')
      if $activeItem?.data().class is NFClass.PageComp
        model =
          target: $activeItem.data()
          command: "add-small"
          settings: currentSettings
        hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .switch-to-page').click (e) ->
    unless $(this).hasClass 'disabled'
      $activeItem = $('#selector-list li.active')
      if $activeItem?.data().class is NFClass.PageComp
        model =
          target: $activeItem.data()
          command: "switch-to-page"
          settings: currentSettings
        hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .expose').click (e) ->
    unless $(this).hasClass 'disabled'
      $activeItem = $('#selector-list li.active')
      data = $activeItem?.data()
      if data.class is NFClass.ShapeLayer or data.class is NFClass.HighlightLayer
        model =
          target: data
          command: "expose"
          settings: currentSettings
        hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .expand').click (e) ->
    unless $(this).hasClass 'disabled'
      $activeItem = $('#selector-list li.active')
      data = $activeItem?.data()
      if data.class is NFClass.ShapeLayer or data.class is NFClass.HighlightLayer
        model =
          target: data
          command: "expand"
          settings: currentSettings
        hook "runLayoutCommand(#{JSON.stringify model})"

  $('#layout-panel .bubble-up').click (e) ->
    unless $(this).hasClass 'disabled'
      $activeItem = $('#selector-list li.active')
      data = $activeItem?.data()
      if data.class is NFClass.ShapeLayer or data.class is NFClass.HighlightLayer
        model =
          target: data
          command: "bubble"
          settings: currentSettings
        hook "runLayoutCommand(#{JSON.stringify model})"

  extensionDirectory = csInterface.getSystemPath('extension')
