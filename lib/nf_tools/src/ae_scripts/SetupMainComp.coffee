$.evalFile File($.fileName).path + "/runtimeLibraries.jsx"

setupMainComp = ->
  fileName = decodeURIComponent app.project.file.name
  mainCompName = fileName.substr(0, fileName.indexOf('.')) + ' - MainComp'
  footageFile = app.project.selection[0]
  return alert "Error\nNo footage file selected!" unless footageFile?

  # Check that all the other assets we need exist
  backdropFileName = "nf-bg-v01.ai"
  dotOverlayFileName = "particular-bg-overlay-v01.mov"
  footageLayerName = "GREENSCREEN"
  backdropFile = NFProject.findItem backdropFileName
  dotOverlayFile = NFProject.findItem dotOverlayFileName
  return alert "Error\nCan't find dependent files (backdrop and dot overlay) in the project." unless backdropFile? and dotOverlayFile?

  # Make the main comp and add footage
  mainComp = app.project.items.addComp(mainCompName, 1920, 1080, 1.0, footageFile.duration, 29.9700012207031)
  mainComp.hideShyLayers = yes
  footageLayer = mainComp.layers.add footageFile
  footageLayer.name = footageLayerName
  footageLayer.property('Transform').property("Scale").setValue [50, 50] if footageLayer.hasVideo

  # Get number of markers on layer
  markerStream = footageLayer.property('Marker')
  markerCount = markerStream.numKeys

  # create new background layer
  bgLayer = mainComp.layers.addSolid([1,1,1], 'Background', 1920, 1080, 1)
  bgLayer.moveBefore footageLayer

  # Populate the Parts
  newComps = []
  prevTime = 0
  # Make a folder for the new Precomps
  rootFolder = app.project.rootFolder
  partsFolder = app.project.items.addFolder('Parts')

  # For each marker, duplicate the audio/video layer, set in and out points, then precompose
  for i in [1..markerCount+1]
    duplicatedFootageLayer = footageLayer.duplicate()
    duplicatedFootageLayer.name = footageLayerName
    duplicatedFootageLayer.inPoint = prevTime

    if i is markerCount + 1
      currentTime = duplicatedFootageLayer.outPoint = mainComp.duration
    else
      currentMarker = markerStream.keyValue i
      currentTime = duplicatedFootageLayer.outPoint = markerStream.keyTime i

    newCompName = "Part #{i}"
    newComp = mainComp.layers.precompose [duplicatedFootageLayer.index], newCompName, true
    precomposedFootageLayer = newComp.layers[1]

    # Apply the Animation Preset. NOTE: because of an AE bug, a layer has to be selected to apply a preset. Hence the hack
    # path = Folder(File($.fileName).parent.parent.fsName).fsName + '/lib/NF Greenscreen Preset.ffx'
    # gsPreset = File path
    # precomposedFootageLayer.selected = yes
    # precomposedFootageLayer.applyPreset gsPreset
    # precomposedFootageLayer.selected = no

    backdropLayer = newComp.layers.add backdropFile
    dotOverlayLayer = newComp.layers.add dotOverlayFile
    backdropLayer.name = "NF Backdrop"
    dotOverlayLayer.name = "Dot Overlay"
    dotOverlayLayer.blendingMode = BlendingMode.SCREEN

    logoLayer = backdropLayer.duplicate()
    logoLayer.name = "NF Logo"

    dotOverlayLayer.moveAfter precomposedFootageLayer
    backdropLayer.moveAfter dotOverlayLayer
    logoLayer.moveBefore precomposedFootageLayer

    # Logo Stuff
    newComp.openInViewer()
    backdropLayer.selected = dotOverlayLayer.selected = precomposedFootageLayer.selected = no
    logoLayer.selected = yes
    app.executeCommand 3799 # "Convert to Layered Comp"
    app.executeCommand 4027 # "Freeze On Last Frame"
    logoLayer.selected = no

    logoLayer.collapseTransformation = yes
    logoLayer.transform.opacity.setValue 50
    logoFill = logoLayer.effect.addProperty("ADBE Fill")
    logoColor = logoFill.property("Color")
    logoColor.setValue [0.285,0.75,0.75,1]

    logoComp = logoLayer.source
    logoComp.layer("Layer 6").enabled = no
    logoComp.layer("Layer 5").collapseTransformation = yes

    newComps.push newComp
    newComp.parentFolder = partsFolder

    newCompLayer = mainComp.layers.byName(newCompName)
    unless markerCount is 0
      newCompLayer.inPoint = prevTime - 3
      newCompLayer.outPoint = currentTime + 10

    newComp.bgColor = [1,1,1]
    newCompLayer.moveToBeginning()
    prevTime = currentTime

    logoLayer.selected = yes
    app.executeCommand 2771
    logoLayer.selected = no

  fadeLayer = mainComp.layers.addSolid([1,1,1], 'Fade In/Out', 1920, 1080, 1)
  fadeOpacity = fadeLayer.property('Transform').property('Opacity')
  fadeOpacity.setValuesAtTimes [0, 1, mainComp.duration - 2.5, mainComp.duration], [100, 0, 0, 100]
  fadeLayer.moveToBeginning()

  footageLayer.remove()

  mainComp.dropFrame = yes

app.beginUndoGroup 'Setup Main Comp'

setupMainComp()

app.endUndoGroup()
