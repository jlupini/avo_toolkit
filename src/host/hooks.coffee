try
  openDocument = (location) ->
    alert 'Testing server'
    fileRef = new File(location)
    docRef = app.open(fileRef)
    return

  debug = () ->
    $.level = 2
    debugger

  #
  # Old Tool Panel
  #

  runTool = (toolKey) ->

    for key of toolRegistry
      category = toolRegistry[key]
      choice = category.tools[toolKey] if category.tools[toolKey]?

    return alert "No Tool Selected! (key was #{toolKey})" unless choice?
    if choice.callback?
      app.beginUndoGroup "NF Tool: #{choice.name}"
      choice.callback()
      app.endUndoGroup()
    else
      openScript choice.callbackScript

  #
  # Defaults File
  #
  editDefaultsFile = (newContents) ->
    oldContents = ""
    finalContents = ""
    NFTools.editProjectFile "./.animation_settings.json", (theFileText) =>
      # $.level = 2
      # debugger
      if newContents?
        if newContents is ""
          return finalContents = ""
        else return finalContents = JSON.stringify(newContents)
      else if theFileText?
        return finalContents = theFileText
      else return finalContents = ""

    return finalContents


  #
  # Emphasizer
  #
  makeEmphasisLayer = ->
    selectedLayer = NFProject.singleSelectedLayer()
    return alert "Please select a single layer first" unless selectedLayer?
    selectedLayer.addEmphasisLayer()

  emphasisLayerSelected = ->
    selectedLayer = NFProject.singleSelectedLayer()
    return selectedLayer? and selectedLayer instanceof NFEmphasisLayer

  setEmphasisProperties = (paramsJSON) ->
    selectedLayer = NFProject.singleSelectedLayer()
    return alert "Please select a single emphasis layer" unless selectedLayer?

    params = JSON.parse paramsJSON
    return alert "Error - no cylon specified" unless params.name?

    if params.color?
      selectedLayer.effect(params.name).property("Color").setValue params.color
    if params.thickness?
      selectedLayer.effect(params.name).property("Thickness").setValue params.thickness
    if params.lag?
      selectedLayer.effect(params.name).property("Lag").setValue params.lag

  getEmphasisProperties = ->
    selectedLayer = NFProject.singleSelectedLayer()
    return alert "Please select a single layer first" unless selectedLayer?

    allEffects = {}
    # Using aequery for the first time
    layer = new aeq.Layer (selectedLayer.$)
    layer.forEachEffect (e) ->
      allEffects[e.name] =
        thickness: e.property("Thickness").value
        lag: e.property("Lag").value
        color: e.property("Color").value
    return allEffects


  #
  # Transition Stuff
  #
  transitionFadeIn = ->
    theLayer = NFProject.singleSelectedLayer()
    return alert "Please select a single layer first" unless theLayer?
    theLayer.fadeIn()
  transitionFadeOut = ->
    theLayer = NFProject.singleSelectedLayer()
    return alert "Please select a single layer first" unless theLayer?
    theLayer.fadeOut()
  transitionSlideIn = ->
    theLayer = NFProject.singleSelectedLayer()
    return alert "Please select a single layer first" unless theLayer?
    theLayer.slideIn()
  transitionSlideOut = ->
    theLayer = NFProject.singleSelectedLayer()
    return alert "Please select a single layer first" unless theLayer?
    theLayer.slideOut()
  transitionClearIn = ->
    theLayer = NFProject.singleSelectedLayer()
    alert "deleting in and out NF transitions"
    return alert "Please select a single layer first" unless theLayer?
    theLayer.removeNFMarkers()
  transitionClearOut = ->
    theLayer = NFProject.singleSelectedLayer()
    alert "deleting in and out NF transitions"
    return alert "Please select a single layer first" unless theLayer?
    theLayer.removeNFMarkers()
  transitionFadeScaleIn = ->
    alert "haven't done this yet"
  transitionFadeScaleOut = ->
    alert "haven't done this yet"

  focusOn = (req) ->
    app.beginUndoGroup "Change Focus (via NF Panel)"

    if req is "all"
      NFProject.activeComp().allLayers().forEach (layer) =>
        layer.setShy no unless layer.getName().indexOf("FlightPath") >= 0

      NFProject.activeComp().$.hideShyLayers = yes
    else if req is "pdf"
      activeComp = NFProject.activeComp()
      activeLayers = activeComp.activeLayers()
      return alert "No layers active!" if activeLayers.isEmpty()

      looseLayers = new NFLayerCollection
      activeLayers.forEach (layer) =>
        looseLayers.add layer unless layer instanceof NFCitationLayer or layer.getName().indexOf("Backing for") >= 0
        looseLayers.add layer.getChildren(yes) unless layer.is activeComp.greenscreenLayer()

        # Add members in PDF group if we can find one
        if layer instanceof NFPageLayer
          group = layer.getPaperLayerGroup()
          if group?
            looseLayers.add group.getMembers()
            looseLayers.add group.paperParent

      activeComp.allLayers().forEach (layer) =>
        layer.setShy not looseLayers.containsLayer(layer)

      activeComp.$.hideShyLayers = yes
    else if req is "active"
      activeComp = NFProject.activeComp()
      activeLayers = activeComp.activeLayers()
      return alert "No layers active!" if activeLayers.isEmpty()

      tightLayers = new NFLayerCollection
      activeLayers.forEach (layer) =>
        tightLayers.add layer unless layer instanceof NFCitationLayer or layer.getName().indexOf("Backing for") >= 0
        if layer instanceof NFPageLayer
          group = layer.getPaperLayerGroup()
          if group?
            tightLayers.add group.paperParent
            tightLayers.add group.getCitationLayer()

            time = activeComp.getTime()
            group.getControlLayers().forEach (control) =>
              tightLayers.add control if control.$.inPoint <= time and control.$.outPoint >= time

      activeComp.allLayers().forEach (layer) =>
        layer.setShy not tightLayers.containsLayer(layer)

      activeComp.$.hideShyLayers = yes
    else alert "Error: Invalid focus request"

    app.endUndoGroup()

  setBlendingMode = (mode) ->
    app.beginUndoGroup "Set Blend Mode (via NF Panel)"
    if mode is "overlay"
      modeCode = BlendingMode.OVERLAY
    else if mode is "multiply"
      modeCode = BlendingMode.MULTIPLY
    else if mode is "screen"
      modeCode = BlendingMode.SCREEN
    else
      modeCode = BlendingMode.NORMAL

    NFProject.selectedLayers().forEach (layer) =>
      layer.$.blendingMode = modeCode
    app.endUndoGroup()

  runLayoutCommand = (model) ->
    try
      app.beginUndoGroup "Run Layout Command"
      activeComp = NFProject.activeComp()
      activeComp.runLayoutCommand model
      app.endUndoGroup()
    catch e
      alert "Error calling hook `runLayoutCommand`: #{e.message}"

  openComp = (model) ->
    aeq.getComp(model.name).openInViewer()

  getFullPDFTree = ->
    # Make an object with all the PDFs
    try
      contentTree = {}
      outputTree =
        pdfs: []
      allPageComps = NFProject.allPageComps()

      for pageComp in allPageComps
        pdfNumber = pageComp.getPDFNumber()

        contentTree[pdfNumber] = [] unless contentTree[pdfNumber]?
        contentTree[pdfNumber].push pageComp

      for key of contentTree
        thisPDF = NFPDF.fromPDFNumber(key).simplify()
        thisPDF.pages = []

        pageCompArr = contentTree[key]
        for pageComp in pageCompArr
          thisPage = pageComp.simplify()
          thisPage.shapes = []

          # Collect only the shape layers
          pageLayers = pageComp.allLayers()
          shapeLayers = new NFLayerCollection
          pageLayers.forEach (layer) =>
            shapeLayers.add layer if layer.$ instanceof ShapeLayer

          unless shapeLayers.isEmpty()
            shapeLayers.forEach (shapeLayer) =>
              thisPage.shapes.push shapeLayer.simplify()

          thisPDF.pages.push thisPage

        outputTree.pdfs.push thisPDF

      return JSON.stringify outputTree
    catch e
      return e


  getPollingData = ->
    # NOTE: We use native objects here to speed up polling
    model = {}
    activeComp = app.project.activeItem
    return "undefined" unless activeComp?
    try
      if activeComp? and activeComp instanceof CompItem
        if activeComp.simpleReflection?
          compType = activeComp.simpleReflection().class

          if compType is "NFPartComp"
            # check for active page and PDF
            activePage = null
            allLayers = activeComp.layers
            unless allLayers.length is 0
              prevLayer = null
              for i in [1..(allLayers.length)]
                thisLayer = allLayers[i]
                if thisLayer.source?.name.includes("NFPage") and not thisLayer.name.includes('[ref]') and thisLayer.opacity.value isnt 0 and thisLayer.inPoint <= activeComp.time <= thisLayer.outPoint
                  if prevLayer?
                    if thisLayer.index < prevLayer.index
                      activePage = thisLayer
                  else
                    activePage = thisLayer
                  prevLayer = thisLayer

            if activePage?
              model.activePDF = activePage.source.getPDFNumber()
              model.activePage = activePage.simpleReflection()
          else if compType is "NFPageComp"
            allLayers = activeComp.layers
            highlightLayers = []
            unless allLayers.length is 0
              prevLayer = null
              for i in [1..(allLayers.length)]
                thisLayer = allLayers[i]
                if thisLayer instanceof ShapeLayer
                  if thisLayer.property("Effects").property("AV Highlighter")?
                    if thisLayer.property("Effects").property("Rect Hash")?
                      highlightLayers.push
                        name: thisLayer.name
                        index: thisLayer.index
                        rectHash: thisLayer.property("Effects").property("Rect Hash").property("Point").value
            model.highlightLayers = highlightLayers

          selectedAVLayers = activeComp.selectedLayers
          if selectedAVLayers.length is 0
            layerType = "no-layer"
          else if selectedAVLayers.length is 1
            selectedLayer = selectedAVLayers[0]
            singleSelectedLayerSimplified = selectedLayer.simpleReflection()
            layerType = singleSelectedLayerSimplified.class

            #Add the FX
            model.effects = []
            # Using aequery for the first time
            aeqLayer = new aeq.Layer selectedLayer
            aeqLayer.forEachEffect (e, i) =>
              if e.matchName.includes("AV_")
                # $.bp()
                model.effects.push
                  name: e.name
                  matchName: e.matchName
                  properties: {}
                effectIndex = model.effects.length - 1
                e.forEach (prop) =>
                  model.effects[effectIndex].properties[prop.name] =
                    value: prop.value

          else layerType = "multiple-layers"

          # Selected Layer Names
          model.selectedLayers = []
          if singleSelectedLayerSimplified?
            model.selectedLayers.push singleSelectedLayerSimplified
          else if selectedAVLayers.length > 0
            for i in [0..(selectedAVLayers.length-1)]
              simpLayer = selectedAVLayers[i].simpleReflection()
              model.selectedLayers.push simpLayer

          model.bodyClass = "#{layerType} #{compType}"
        else
          return new Error "Cannot get polling data — the active comp doesn't have a simpleReflection method"

      else
        model.bodyClass = "no-comp"

      return JSON.stringify model
    catch e
      return new Error "Cannot get polling data. Failed with message: #{e.message}"

  getActivePageFile = ->
    activeComp = NFProject.activeComp()
    if activeComp instanceof NFPageComp and activeComp.getPDFLayer().$.source?
      return activeComp.getPDFLayer().$.source.file.fsName
    else return null

  processRawAnnotationData = (rawData) ->
    return NFPDFManager.processRawAnnotationData rawData

  toggleGuideLayers = () ->
    NFProject.toggleGuideLayers()

  convertShapeToHighlight = () ->
    app.beginUndoGroup "Convert Shape to Highlight"

    selectedLayer = NFProject.selectedLayers()?.get(0)
    return alert "No Valid Shape Layer Selected" unless selectedLayer? and selectedLayer instanceof NFShapeLayer
    lineCount = parseInt prompt('How many initial highlight lines would you like to create?')
    # Create the highlight effect
    newName = selectedLayer.getName().replace("Imported PDF Shape: ", "")
    for key, testColor of NFHighlightLayer.COLOR
      newColor = testColor if newName.indexOf(testColor.str) >= 0
    selectedLayer.containingComp().createHighlight
      shapeLayer: selectedLayer
      lines: lineCount
      name: newName
      color: newColor ? NFHighlightLayer.COLOR.YELLOW


    selectedLayer.remove()

    app.endUndoGroup()

  deleteHighlightAtIndex = (idx) ->
    app.beginUndoGroup "Delete Highlight"
    idx = parseInt idx

    targetComp = NFProject.activeComp()
    targetComp.$.layer(idx).remove()

    app.endUndoGroup()

  splitHighlightAtIndex = (idx) ->
    app.beginUndoGroup "Split Highlight"
    idx = parseInt idx

    targetComp = NFProject.activeComp()
    targetLayer = new NFHighlightLayer(targetComp.$.layer(idx))
    targetLayer.split()

    app.endUndoGroup()

  addGaussy = () ->
    app.beginUndoGroup "Add Gaussy"
    NFProject.activeComp().addGaussy()
    app.endUndoGroup()

  addBrowser = () ->
    app.beginUndoGroup "Add Browser"
    activeComp = NFProject.activeComp()
    activeComp.addBrowserWindow activeComp.selectedLayers()
    app.endUndoGroup()

  unlinkHighlightAtIndex = (idx) ->
    app.beginUndoGroup "Unlink Highlight"

    idx = parseInt idx

    targetComp = NFProject.activeComp()
    targetLayer = new NFHighlightLayer(targetComp.$.layer(idx))

    targetLayer.effect("Rect Hash").remove()

    app.endUndoGroup()

  changeLineCountForHighlightAtIndex = (idx, delta) ->
    app.beginUndoGroup "Change Line Count"

    idx = parseInt idx
    delta = parseInt delta

    targetComp = NFProject.activeComp()
    targetLayer = new NFHighlightLayer(targetComp.$.layer(idx))

    targetLayer.changeLineCount delta

    app.endUndoGroup()

  createHighlightFromAnnotation = (annotationDataString) ->
    app.beginUndoGroup "Create Highlight from Annotation"

    annotData = JSON.parse annotationDataString

    targetComp = NFProject.activeComp()

    # Actually add the shapes and stuff
    annotationLayer = targetComp.addShapeLayer()
    annotationLayer.addRectangle
      fillColor: annotData.color
      rect: annotData.rect

    annotationLayer.transform().scale.setValue targetComp?.getPDFLayer().transform().scale.value

    if annotData.lineCount is 0
      annotationLayer.transform("Opacity").setValue 20
      annotationLayer.setName "Imported PDF Shape: #{annotData.cleanName}"
    else
      for key, testColor of NFHighlightLayer.COLOR
        newColor = testColor if annotData.colorName.indexOf(testColor.str) >= 0

      # Create the highlight effect
      targetComp.createHighlight
        shapeLayer: annotationLayer
        lines: annotData.lineCount
        name: annotData.cleanName
        color: newColor
        rectHash: annotData.rectHash

      annotationLayer.remove()

    app.endUndoGroup()

  linkHighlightToSelectedLayer = (annotationDataString) ->
    app.beginUndoGroup "Link Existing Highlight to Annotation"

    annotData = JSON.parse annotationDataString

    targetComp = NFProject.activeComp()

    selectedLayers = targetComp.selectedLayers()
    if selectedLayers.count() is 1 and selectedLayers.get(0) instanceof NFHighlightLayer
      rectHash = annotData.rectHash

      hashProp = selectedLayers.get(0).addEffect('ADBE Point Control')
      hashProp.property("Point").setValue rectHash
      hashProp.name = "Rect Hash"

    else
      alert "Error: Please try again with a single highlight layer selected."

    app.endUndoGroup()

  clearFMFTransition = () ->
    app.beginUndoGroup "Clear FMF Transitions"
    NFProject.activeComp().selectedLayers().forEach (theLayer) =>
      theLayer.effect("Transition Type")?.remove()
      theLayer.effect("Position Override")?.remove()
      theLayer.effect("Scale Override")?.remove()
      theLayer.removeNFMarkers()
      theLayer.transform("Position").expression = ""
    app.endUndoGroup()

  applyFMFTransition = (options) ->
    app.beginUndoGroup "FMF Transition"
    dropdownItems = [
      'Fullscreen'
      'Splitscreen'
      'Custom'
    ]

    transitionDuration = 1

    mainComp = NFProject.activeComp()
    selectedLayers = mainComp.selectedLayers()
    switch selectedLayers.count()
      when 0 then alert "Error: No layer selected"
      when 1, 2
        if selectedLayers.count() is 2
          if options.slide is no
            alert "Error: Two layers selected but slide wasn't chosen"
          else
            # Overlap if they're not already overlapped
            if selectedLayers.get(0).$.inPoint < selectedLayers.get(1).$.inPoint
              slide1 = selectedLayers.get(0)
              slide2 = selectedLayers.get(1)
            else
              slide1 = selectedLayers.get(1)
              slide2 = selectedLayers.get(0)

            if slide2.$.inPoint + mainComp.$.frameDuration >= slide1.$.outPoint
              slide2.$.startTime = slide2.$.startTime - transitionDuration / 2
              slide2.$.outPoint = slide2.$.outPoint + transitionDuration / 2
              slide1.$.outPoint = slide1.$.outPoint + transitionDuration / 2

        # else
        #   do single stuff!

        selectedLayers.forEach (slideLayer) =>
          # Add the expression controls
          slideEffects = slideLayer.effects()

          unless slideEffects.property("Transition Type")?

            dropdownEffect = slideEffects.addProperty('ADBE Dropdown Control')
            temp = dropdownEffect.property(1).setPropertyParameters(dropdownItems)
            temp.propertyGroup(1).name = "Transition Type"
            temp.setValue(options.footageType + 1)

            positionOverride = slideEffects.addProperty('ADBE Point Control')
            positionOverride.property(1).setValue([960,540])
            positionOverride.name = "Position Override"

            scaleOverride = slideEffects.addProperty('ADBE Slider Control')
            scaleOverride.property(1).setValue(100)
            scaleOverride.name = "Scale Override"

          posProp = slideLayer.transform("Position")
          if options.slide
            offscreenPosStartValue = [posProp.value[0] + slideLayer.$.width, posProp.value[1],0]
            offscreenPosEndValue = [posProp.value[0] - slideLayer.$.width, posProp.value[1],0]
            if selectedLayers.count() is 2
              if slideLayer.is slide1
                options.out = yes
                options.in = no
              else
                options.in = yes
                options.out = no

          else
            offscreenPosStartValue = offscreenPosEndValue = [posProp.value[0], posProp.value[1] + slideLayer.$.height, 0]

          slideLayer.addInOutMarkersForProperty
            property: posProp
            length: transitionDuration
            startEquation: if options.in then EasingEquation.quint.inOut else null
            endEquation: if options.out then EasingEquation.quint.inOut else null
            startValue: if options.in then offscreenPosStartValue else null
            endValue: if options.out then offscreenPosEndValue else null
      else alert "Error: Too many layers selected"
    app.endUndoGroup()

catch e
  alert e
