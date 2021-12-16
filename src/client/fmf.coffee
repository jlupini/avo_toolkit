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
          if (path.indexOf('jl_pdf_manager') >= 0) {
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

  $('#error-bar').click ->
    $(this).hide()

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

      if not res?
        return console.log "empty result!"

      if requestTime > POLLING_TIMEOUT and smartTimer?
        timerCounter = 0
        $('#smart-toggle').click()
        return console.log "turning off smart updates - request took too long"

      if res.length is 0
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
          if data.selectedLayers.length is 1
            $("#layer-name").text(data.selectedLayers[0].name)
            $("#buttons button").removeClass('disabled')
            $("#slide-transition").addClass("disabled")
          else if data.selectedLayers.length is 0
            $("#layer-name").text("No Layer")
            $("#buttons button").addClass('disabled')
          else if data.selectedLayers.length is 2
            $("#layer-name").text("Two Layers")
            $("#buttons button").addClass('disabled')
            $("#slide-transition").removeClass("disabled")
          else
            $("#layer-name").text("Many Layers")
            $("#buttons button").addClass('disabled')

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

  $('#fullscreen-in').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 0
      slide: no
      in: yes
      out: no
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#fullscreen-both').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 0
      slide: no
      in: yes
      out: yes
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#fullscreen-out').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 0
      slide: no
      in: no
      out: yes
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#splitscreen-in').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 1
      slide: no
      in: yes
      out: no
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#splitscreen-both').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 1
      slide: no
      in: yes
      out: yes
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#splitscreen-out').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 1
      slide: no
      in: no
      out: yes
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#slide-in').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 0
      slide: yes
      in: yes
      out: no
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#slide-both').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 0
      slide: yes
      in: yes
      out: yes
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#slide-out').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 0
      slide: yes
      in: no
      out: yes
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#slide-transition').click ->
    return null if $(this).hasClass 'disabled'
    options =
      footageType: 0
      slide: yes
      in: yes
      out: yes
    hook "applyFMFTransition(#{JSON.stringify(options)})"

  $('#erase-transitions').click ->
    return null if $(this).hasClass 'disabled'
    hook "clearFMFTransition()"





  extensionDirectory = csInterface.getSystemPath('extension')
