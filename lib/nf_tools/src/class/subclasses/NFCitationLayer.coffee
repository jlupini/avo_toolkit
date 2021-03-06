###*
Creates a new NFCitationLayer from a given AVLayer or NFLayer
@class NFCitationLayer
@classdesc Subclass of {@link NFLayer} for a citation layer
@param {AVLayer | NFLayer} layer - the target AVLayer or NFLayer
@property {AVLayer} layer - the wrapped AVLayer
@extends NFLayer
###
class NFCitationLayer extends NFLayer
  constructor: (layer) ->
    NFLayer.call(this, layer)
    @
  toString: ->
    return "NFCitationLayer: '#{@$.name}'"

  ###*
  Provides an object to be easily converted to JSON for the CEP Panel
  @memberof NFCitationLayer
  @returns {Object} the CEP Panel object
  ###
  simplify: ->
    obj = NFLayer.prototype.simplify.call @
    obj.class = "NFCitationLayer"
    return obj

  ###*
  Ends an active citation visibility marker at the given time
  @memberof NFCitationLayer
  @param {float} [time=currTime] - the time to end the marker
  @returns {NFCitationLayer} self
  ###
  hide: (time) ->
    time = time or @containingComp().getTime()

    markers = @markers()
    citationMarkers = []
    if markers.numKeys > 0
      for idx in [1..markers.numKeys]
        thisMarker = markers.keyValue idx
        thisTime = markers.keyTime idx
        thisEndTime = thisTime + thisMarker.duration
        if thisMarker.comment is "Citation"
          if thisTime <= time < thisEndTime
            # We're trying to start inside an existing marker
            # So just end it here
            newDuration = time - thisTime
            markers.removeKey idx
            @addMarker
              time: thisTime
              comment: "Citation"
              duration: newDuration
            return @


  ###*
  Adds a citation visible marker at the given time
  @memberof NFCitationLayer
  @param {float} [time=currTime] - the time to add the marker
  @param {float} [duration=5] - the duration of the marker
  @returns {NFCitationLayer} self
  ###
  show: (time, duration) ->
    time = time or @containingComp().getTime()
    duration = duration or 5
    endTime = time + duration

    markers = @markers()
    citationMarkers = []
    if markers.numKeys > 0
      for idx in [1..markers.numKeys]
        thisMarker = markers.keyValue idx
        thisTime = markers.keyTime idx
        thisEndTime = thisTime + thisMarker.duration
        if thisMarker.comment is "Citation"
          if thisTime <= time < thisEndTime
            # We're trying to start inside an existing marker
            # So just extend the end of the existing one.
            newDuration = endTime - thisTime
            thisMarker.duration = newDuration if newDuration > thisMarker.duration
            return @
          if thisTime <= endTime < thisEndTime
            # We're trying to end this marker inside an existing one
            # So just extend the start of the existing one back
            delta = thisTime - time
            newDuration = thisMarker.duration + delta
            markers.removeKey idx
            @addMarker
              time: time
              comment: "Citation"
              duration: newDuration
            return @


    @addMarker
      time: time
      comment: "Citation"
      duration: duration
    return @


NFCitationLayer = Object.assign NFCitationLayer,

  ###*
  Returns whether or not the given AVLayer is a valid Citation Layer
  @memberof NFCitationLayer
  @param {AVLayer} the layer to check
  @returns {boolean} whether the AV layer is a valid citation layer
  ###
  isCitationLayer: (theLayer) ->
    return theLayer.name.indexOf("Citation") >= 0

  ###*
  Returns the folder where citation comps live. Makes one if it doesn't exist.
  @memberof NFCitationLayer
  @returns {FolderItem} the folder where the cite comps live
  ###
  folder: ->
    citeFolder = NFProject.findItem "Citations"
    unless citeFolder
      assetsFolder = NFProject.findItem "Assets"
      citeFolder = assetsFolder.items.addFolder "Citations"
    return citeFolder

  ###*
  Fetches the citation from the citations.csv file found in the project
  directory.
  @memberof NFCitationLayer
  @param {NFPDF | int} thePDF - the PDF to make the comp for, or its number
  @returns {NFComp} the new comp
  @throw Throws an error if citations.csv could not be found or empty
  ###
  fetchCitation: (thePDF) ->
    pdfKey = if thePDF instanceof NFPDF then thePDF.getPDFNumber() else thePDF
    if NFTools.testProjectFile "citations.csv"
      citationsFile = NFTools.readProjectFile "citations.csv", yes
      citationArray = citationsFile.splitCSV()

      throw new Error "Empty Citation array" unless citationArray.length > 0

      # Figure out our start column
      startColumn = 0
      throw new Error "No columns found in citation file" unless citationArray[0].length > 0
      for citeLineItemIdx in [0..citationArray[0].length-1]
        citeLineItem = citationArray[0][citeLineItemIdx]
        if citeLineItem isnt ""
          startColumn = citeLineItemIdx
          break

      throw new Error "Not enough columns in citation file" unless citationArray[0].length >= startColumn

      citeObj = {}
      for citeLine in citationArray
        newKey = citeLine[startColumn]
        newVal = citeLine[startColumn + 1]
        citeObj[newKey] = newVal

      if citeObj[pdfKey]?
        throw new Error "Found a citation for PDF #{pdfKey} but it's blank. Check citation file formatting." if citeObj[pdfKey] is ""
        # Check if we need to convert to an NF-Style citation
        inputCite = citeObj[pdfKey]
        if inputCite.split(".").length > 3 and inputCite.indexOf(";") >= 0
          try
            # Start with the three sentences
            sentenceSplit = inputCite.split(".")

            sentences = []
            for sentence in sentenceSplit
              trimmed = sentence.trim()
              if trimmed.length isnt 0
                sentences.push trimmed

            # Last sentence should be the year and issue/volume/page
            identifierSplit = sentences[sentences.length-1].split(";")
            journalName = sentences[sentences.length-2]

            finalCite = "#{journalName}. #{identifierSplit[1]}."
          catch e
            return "PDF #{pdfKey} - appears to have a long-form citation that cannot be converted"
        else finalCite = inputCite
        return finalCite
      else return "PDF #{pdfKey} - NO CITATION FOUND IN FILE! FIX ME LATER."

    if app.citationWarning isnt app.project.file.name
      alert "Warning!\nNo citation file found in the project directory. If your
             project directory does not contain a file called 'citations.csv',
             then citations will not be automatically imported and you'll have
             to fix them all after you're done animating. You'll only receive
             this warning once for this project, during this AE session."
      app.citationWarning = app.project.file.name

    return "#{thePDF.getName()} - NO CITATION FILE FOUND. FIX ME LATER."

  ###*
  Returns the citation layer/comp name for a given PDF
  @memberof NFCitationLayer
  @param {NFPDF} thePDF - the PDF to make the name for
  @returns {String} the citation layer/comp name
  ###
  nameFor: (thePDF) ->
    return "#{thePDF.getPDFNumber()} - Citation"

  ###*
  Returns the citation layer/comp name for a given PDF
  @memberof NFCitationLayer
  @param {String} text - the text of the citation
  @returns {String} the citation layer/comp name
  ###
  nameForLoose: (text) ->
    return "#{text} - Citation"



  ###*
  Creates a new citation composition. Note that citation comps, while NFComps,
  do not have their own unique wrapper class.
  @memberof NFCitationLayer
  @param {NFPDF} thePDF - the PDF to make the comp for
  @returns {NFComp} the new comp
  ###
  newCitationComp: (name, citationString, style = '2020') ->
    NFTools.log "Creating new citation comp for PDF: #{name}", "NFCitationLayer"

    citeFolder = NFCitationLayer.folder()
    citeComp = citeFolder.items.addComp(name, 1920, 1080, 1, 600, 30)

    # Note: we're working with raw layers and comps and stuff here

    if style is '2020'
      # Create and format text layer
      fontSize = 37
      textLayer = citeComp.layers.addBoxText [1920, fontSize + 20], citationString
      textLayer_TextProp = textLayer.property('ADBE Text Properties').property('ADBE Text Document')
      textLayer_TextDocument = textLayer_TextProp.value
      textLayer_TextDocument.resetCharStyle()
      textLayer_TextDocument.fillColor = [1,1,1]
      textLayer_TextDocument.strokeWidth = 0
      textLayer_TextDocument.font = "Open Sans"
      textLayer_TextDocument.justification = ParagraphJustification.RIGHT_JUSTIFY
      textLayer_TextDocument.fontSize = fontSize
      textLayer_TextDocument.applyFill = true
      textLayer_TextDocument.applyStroke = false
      textLayer_TextProp.setValue textLayer_TextDocument
      textLayer.boxText = true

      sourceRectText = textLayer.sourceRectAtTime(0, false)
      textLayer.anchorPoint.setValue [sourceRectText.left + sourceRectText.width, sourceRectText.top]
      textLayer.position.setValue [citeComp.width - 20,45,0]
    else
      # Create background layer and add effects
      bgSolid = citeComp.layers.addSolid [0,0,0], 'colorCorrect', citeComp.width, citeComp.height, 1
      bgSolid.adjustmentLayer = true
      bgSolid.name = 'Background Blur'
      bgBlur = bgSolid.property('Effects').addProperty('ADBE Gaussian Blur 2')
      bgBlur.property('Blurriness').setValue 35
      bgBrightness = bgSolid.property('Effects').addProperty('ADBE Brightness & Contrast 2')
      bgBrightness.property('Brightness').setValue -148
      bgBrightness.property("Use Legacy (supports HDR)").setValue 1

      # Create and format text layer
      fontSize = 37
      textLayer = citeComp.layers.addBoxText [(fontSize + 20) * citationString.length, fontSize + 20], citationString
      textLayer_TextProp = textLayer.property('ADBE Text Properties').property('ADBE Text Document')
      textLayer_TextDocument = textLayer_TextProp.value
      textLayer_TextDocument.resetCharStyle()
      textLayer_TextDocument.fillColor = [1,1,1]
      textLayer_TextDocument.strokeWidth = 0
      textLayer_TextDocument.font = "Proxima Nova"
      textLayer_TextDocument.justification = ParagraphJustification.RIGHT_JUSTIFY
      textLayer_TextDocument.fontSize = fontSize
      textLayer_TextDocument.applyFill = true
      textLayer_TextDocument.applyStroke = false
      textLayer_TextProp.setValue textLayer_TextDocument
      textLayer.boxText = true

      # Position text layer
      sourceRectText = textLayer.sourceRectAtTime(0, false)
      textLayer.anchorPoint.setValue [sourceRectText.left + sourceRectText.width, sourceRectText.top]
      textBoxSizeX = textLayer_TextDocument.boxTextSize[0]
      textBoxSizeY = textLayer_TextDocument.boxTextSize[1]

      # Create mask and position
      maskShape = new Shape
      maskShape.vertices = [
        [0,sourceRectText.height + 20]
        [0,0]
        [sourceRectText.width + 25,0]
        [sourceRectText.width + 25,sourceRectText.height + 20]
      ]
      maskShape.closed = true
      bgMask = bgSolid.property('Masks').addProperty('Mask')
      maskPath = bgMask.property('Mask Path')
      maskPath.setValue maskShape

      # Final Positions
      sourceRectBgMask = bgSolid.sourceRectAtTime(0, false)
      bgSolid.anchorPoint.setValue [sourceRectText.width + 25,0]
      bgSolid.position.setValue [citeComp.width,20,0]
      textLayer.position.setValue [citeComp.width - 10,30,0]

      # Order Layers Correctly
      textLayer.moveBefore bgSolid

    return new NFComp citeComp

  ###*
  Creates a new NFCitationLayer for the given group
  @memberof NFCitationLayer
  @param {NFPaperLayerGroup} group - the group to make the citation layer for
  @returns {NFCitationLayer} the new citation layer
  ###
  newCitationLayer: (group) ->
    throw new Error "Missing group" unless group instanceof NFPaperLayerGroup

    thePDF = NFPDF.fromGroup group
    compName = NFCitationLayer.nameFor thePDF
    citationComp = NFProject.findItem compName

    # Make a new comp if one doesn't exist for this PDF
    if citationComp?
      citationComp = new NFComp citationComp
    else
      citationComp = NFCitationLayer.newCitationComp compName, NFCitationLayer.fetchCitation(thePDF)

    NFTools.log "Creating new citation layer for Group: #{group.toString()}", "static NFCitationLayer"
    # Add the Layer
    citeLayer = group.containingComp().insertComp
      comp: citationComp
      below: group.paperParent
      time: group.paperParent.$.inPoint
    citeLayer.$.collapseTransformation = yes
    citeLayer.$.label = 12

    invertProp = citeLayer.property('Effects').addProperty('ADBE Invert')
    invertProp.property("Blend With Original").expression = NFTools.readExpression "citation-invert-expression",
      INVERT_DURATION: 0.5

    if group.getPages().isEmpty()
      citeLayer.$.startTime = group.containingComp().getTime()
    else
      citeLayer.$.startTime = group.getPages().getEarliestLayer().$.inPoint

    sourceExpression = NFTools.readExpression "citation-opacity-expression"
    citeLayer.transform().property("Opacity").expression = sourceExpression

    return citeLayer

  ###*
  Creates a new  looseNFCitationLayer for the given string
  @memberof NFCitationLayer
  @param {String} name - the string to make the citation layer for
  @param {NFComp} containingComp - the comp to put it in
  @param {float} [time=currentTime] - the time to start it at
  @returns {NFCitationLayer} the new citation layer
  ###
  newLooseCitationLayer: (name, containingComp, time) ->
    compName = NFCitationLayer.nameForLoose name
    citationComp = NFProject.findItem compName

    # Make a new comp if one doesn't exist for this PDF
    citationComp = NFCitationLayer.newCitationComp compName, name unless citationComp?

    NFTools.log "Creating new loose citation layer for String: #{name}", "static NFCitationLayer"
    # Add the Layer
    citeLayer = containingComp.insertComp
      comp: citationComp
      time: time ? containingComp.getTime()
    citeLayer.$.collapseTransformation = yes

    invertProp = citeLayer.property('Effects').addProperty('ADBE Invert')
    invertProp.property("Blend With Original").expression = NFTools.readExpression "citation-invert-expression",
      INVERT_DURATION: 0.5

    sourceExpression = NFTools.readExpression "citation-opacity-expression"
    citeLayer.transform().property("Opacity").expression = sourceExpression

    return citeLayer
