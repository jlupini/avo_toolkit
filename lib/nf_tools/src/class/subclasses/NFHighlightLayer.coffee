###*
Creates a new NFHighlightLayer from a given AVLayer
@class NFHighlightLayer
@classdesc Subclass of {@link NFLayer} for a highlight layer
@param {AVLayer | NFLayer} layer - the target AVLayer or NFLayer
@property {AVLayer} layer - the wrapped AVLayer
@extends NFLayer
@throws Will throw an error if not given an AVLayer with a highlight
###
class NFHighlightLayer extends NFLayer
  constructor: (layer) ->
    NFLayer.call(this, layer)
    unless NFHighlightLayer.isHighlightLayer(@$)
      throw new Error "NF Highlight Layer must contain a shape layer with the 'AV Highlighter' effect"
    @
  toString: ->
    return "NFHighlightLayer: '#{@$.name}'"

  ###*
  Provides an object to be easily converted to JSON for the CEP Panel
  @memberof NFHighlightLayer
  @returns {Object} the CEP Panel object
  ###
  simplify: ->
    obj = NFLayer.prototype.simplify.call @
    obj.class = "NFHighlightLayer"
    return obj

  ###*
  Returns whether this highlight is bubbled up or not
  @memberof NFHighlightLayer
  @returns {boolean} if the highlight is bubbled up
  ###
  isBubbled: ->
    return @highlighterEffect().property("Spacing").expressionEnabled

  ###*
  Returns whether this highlight is has a broken expression
  @memberof NFHighlightLayer
  @returns {boolean} if the highlight has a broken expression
  ###
  isBroken: ->
    return @highlighterEffect().property("Spacing").expressionError isnt ""

  ###*
  Returns the connected NFHighlightControlLayer if it exists
  @memberof NFHighlightLayer
  @returns {NFHighlightControlLayer | null} the control layer or null
  ###
  getControlLayer: ->

    argumentOfPropertyFromExpression = (property, expression) ->
      propertyIndex = expression.indexOf(property + "(")
      if propertyIndex > 0
      	# The +1 is to account for the Open bracket
        startIdx = propertyIndex + property.length + 1
        result = expression.slice(startIdx)
        endIdx = result.indexOf(")")
        result = result.substr(0, endIdx)
        return result.stripQuotes()
      return null

    if @isBubbled()
      expression = @highlighterEffect().property("Spacing").expression
      compName = argumentOfPropertyFromExpression("comp", expression)
      layerName = argumentOfPropertyFromExpression("layer", expression)
      comp = new NFComp NFProject.findItem(compName)

      # This is to deal with the possibility that there are two layers with the
      # same name in the comp...
      if comp?
        possibleLayers = comp.layersWithName layerName
        if possibleLayers.isEmpty()
          return null
        else
          return possibleLayers.get 0

  ###*
  Returns an array of Spotlight mask Properties that reference this layer
  @memberof NFHighlightLayer
  @returns {Property[]} a potentially empty array of spotlight
  mask Property objects
  ###
  getSpotlightMasks: ->
    folder = NFProject.findItem "Parts"
    items = NFProject.searchItems("Part", folder)
    spotlightLayers = new NFLayerCollection

    for item in items
      part = new NFPartComp item
      spotlightLayer = part.layerWithName NFSpotlightLayer.nameForPDFNumber(@getPDFNumber())
      spotlightLayers.add spotlightLayer if spotlightLayer?

    if spotlightLayers.isEmpty()
      return []
    else
      targetMasks = []
      spotlightLayers.forEach (spotlight) =>
        possibleMask = spotlight.mask @getName()
        targetMasks.push possibleMask if possibleMask?
      return targetMasks

  ###*
  Returns the NFPageComp this highlight lives in
  @memberof NFHighlightLayer
  @returns {NFPageComp} the containing page item for the highlight
  ###
  getPageComp: ->
    return new NFPageComp(@$.containingComp)

  ###*
  Returns the NFPDF this highlight lives in
  @memberof NFHighlightLayer
  @returns {NFPDF} the PDF
  ###
  getPDF: ->
    return NFPDF.fromPDFNumber @getPDFNumber()

  ###*
  Returns the PDF number for the containing comp
  @memberof NFHighlightLayer
  @returns {String} the PDF number
  ###
  getPDFNumber: ->
    return @containingComp().getPDFNumber()

  ###*
  Returns the AV Highlighter effect
  @memberof NFHighlightLayer
  @returns {Property} the AV Highlighter Property for this highlight
  ###
  highlighterEffect: ->
    return @$.Effects.property("AV_Highlighter")

  ###*
  Returns the split point value
  @memberof NFHighlightLayer
  @returns {Array} the x and y points for the split
  ###
  getSplitPoint: ->
    return @effect("Split Point")?.property("Point").value

  ###*
  Sets the split point value, or resets it if no value passed
  @memberof NFHighlightLayer
  ###
  setSplitPoint: (newPoint = [0,0]) ->
    unless @effect("Split Point")?
      splitProp = @addEffect 'ADBE Point Control'
      splitProp.name = "Split Point"
    return @effect("Split Point").property("Point").setValue newPoint

  ###*
  Splits the highlight at the current Split Point, or alerts if that point is invalid
  @memberof NFHighlightLayer
  ###
  split: ->
    splitPoint = @getSplitPoint()
    if not splitPoint?
      return @setSplitPoint()

    splitX = splitPoint[0]
    splitY = splitPoint[1]

    return alert "Please set a valid split point and try again" if splitX is splitY is 0

    # Convert if it's an old-style highlight by using changeLineCount with a delta of 0
    changeLineCount 0 unless @property("Contents").property("Highlight Lines")?
    highlightLines = @property("Contents").property("Highlight Lines").property("Contents")
    lineCount = highlightLines.numProperties

    # Let's figure out which line is closest to the point
    # To do this, we only care about the Y value
    linePath = highlightLines.property(1).property("Contents").property("Line 1 Path").property("Path").value
    lineVerticies = linePath.vertices

    lineStartPoint = lineVerticies[0]
    lineEndPoint = lineVerticies[1]

    lineRelStartPoint = @relativePoint lineStartPoint
    lineRelEndPoint = @relativePoint lineEndPoint

    spacing = @highlighterEffect().property("Spacing").value

    closestLine = null
    for i in [1..lineCount]
      currentLine = i
      verticalDistanceFromLine = Math.abs(lineRelStartPoint[1] + ((i-1) * spacing) - splitY)
      if not closestDistanceSoFar? or verticalDistanceFromLine < closestDistanceSoFar
        closestDistanceSoFar = verticalDistanceFromLine
        closestLine = currentLine

    lineStartX = lineRelStartPoint[0]
    lineEndX = lineRelEndPoint[0]

    splitPercentage = (splitX - lineStartX) / (lineEndX - lineStartX)

    expandLayer = @duplicate()
    expandLayer.setName "#{@getName()} Expand" unless @getName().includes("Expand")

    # Delete all the lines after the closest line on this layer
    unless closestLine is lineCount
      for i in [lineCount..closestLine+1]
        highlightLines.property(i).remove()
    # Delete all the lines before the closest line on the expand
    expHighlightLines = expandLayer.property("Contents").property("Highlight Lines").property("Contents")
    linesToDelete = closestLine - 1
    unless linesToDelete is 0
      for i in [1..linesToDelete]
        expHighlightLines.property(lineCount-linesToDelete+1).remove()

    offsetProp = expandLayer.highlighterEffect().property("Offset")
    offset = offsetProp.value
    offsetProp.setValue [offset[0], offset[1] + spacing * linesToDelete]

    # startOffset = @highlighterEffect().property("Start Offset")
    endOffset = @highlighterEffect().property("End Offset")
    startOffsetExp = expandLayer.highlighterEffect().property("Start Offset")
    # endOffsetExp = expandLayer.highlighterEffect().property("End Offset")

    startOffsetExp.setValue 100 * splitPercentage
    endOffset.setValue 100 * (1 - splitPercentage)

    expandLayer.changeLineCount 0
    @changeLineCount 0

    expandLayer.setSplitPoint()
    @setSplitPoint()

  ###*
  Change line count by the given amount
  @memberof NFHighlightLayer
  @returns {NFHighlightLayer} self
  ###
  changeLineCount: (delta) ->
    highlighterEffect = @highlighterEffect()

    # Check if we need to convert an old-style highlight
    if @property("Contents").property("Highlight Lines")?
      highlightLines = @property("Contents").property("Highlight Lines").property("Contents")
      currentLineCount = highlightLines.numProperties

      lineShape = highlightLines.property(1).property("Contents").property("Line 1 Path").property("Path").value
      for i in [currentLineCount..1]
        highlightLines.property(i).remove()
    else
      currentLineCount = @property("Contents").numProperties
      lineShape = @property("Contents").property(currentLineCount).property("Contents").property("Path 1").property("Path").value

      for i in [currentLineCount..1]
        @property("Contents").property(i).remove()

      group = @property("Contents").addProperty("ADBE Vector Group")
      group.name = "Highlight Lines"
      highlightLines = group.property("Contents")

    newLineCount = currentLineCount + delta
    if newLineCount < 1
      alert "Error:\nCannot reduce line count to zero."
    else

      for i in [1..newLineCount]
        lineGroup = highlightLines.addProperty("ADBE Vector Group")
        lineGroup.name = "Line #{i}"
        lineGroup.property('Transform').property('Position').expression = '[0, effect("AV Highlighter")("Spacing")*' + (i - 1) + ']'
        linePathProp = lineGroup.property("Contents").addProperty("ADBE Vector Shape - Group")
        linePathProp.name = "Line #{i} Path"
        linePathProp.property("ADBE Vector Shape").setValue(lineShape)
        lineTrimProp = lineGroup.property("Contents").addProperty('ADBE Vector Filter - Trim')
        lineTrimProp.property('Start').expression = 'effect("AV Highlighter")("Start Offset")' if i is 1
        lineTrimProp.property('End').expression = NFTools.readExpression "highlight-trim-end-expression",
          LINE_COUNT: newLineCount
          THIS_LINE: i
        lineStrokeProp = lineGroup.property("Contents").addProperty("ADBE Vector Graphic - Stroke")
        lineStrokeProp.property("Color").expression = NFTools.readExpression "highlight-stroke-color-expression"
        lineStrokeProp.property('Stroke Width').expression = 'effect("AV Highlighter")("Thickness")'

    return @


  ###*
  Returns true if the highlight can be bubbled up. In other words, true if not currently bubbled up
  unless it's also broken
  @memberof NFHighlightLayer
  @returns {boolean} whether the highlight can be bubbled up
  ###
  canBubbleUp: ->
    return (not @isBubbled()) or @isBroken()

  ###*
  Fixes the expression after initting if the page layer name changed and there was already an existing expression
  @memberof NFHighlightLayer
  @returns {NFHighlightLayer} self
  ###
  fixExpressionAfterInit: ->
    if @isBubbled()
      for property in NFHighlightLayer.highlighterProperties
        expression = @highlighterEffect().property(property).expression
        @highlighterEffect().property(property).expression = expression.replace(new RegExp(" NFPage", 'g'), " [+]")
    @

  ###*
  Fixes the expression after initting if the page layer name changed and there was already an existing expression
  @memberof NFHighlightLayer
  @param {String} diffLetter - the letter to add
  @returns {NFHighlightLayer} self
  ###
  fixExpressionWithDiffLetter: (diffLetter) ->
    if @isBubbled()
      for property in NFHighlightLayer.highlighterProperties
        expression = @highlighterEffect().property(property).expression
        replString = " [+] (#{diffLetter})\""
        @highlighterEffect().property(property).expression = expression.replace(" [+]\"", replString).replace(" [+]\"", replString)
    @

  ###*
  Attempt to clear expresssion errors
  @memberof NFHighlightLayer
  @returns {NFHighlightLayer} self
  ###
  resetExpressionErrors: ->
    if @isBubbled()
      for property in NFHighlightLayer.highlighterProperties
        expression = @highlighterEffect().property(property).expression
        @highlighterEffect().property(property).expression = ""
        @highlighterEffect().property(property).expression = expression
    @

  ###*
  Disconnects bubbleups in this highlight layer
  @memberof NFHighlightLayer
  @returns {NFHighlightLayer} self
  ###
  disconnect: ->
    # Remove the control layer if it exists
    @getControlLayer()?.remove()

    # Remove any referencing spotlight masks if they exist
    masks = @getSpotlightMasks()
    mask.remove() for mask in masks

    effect = @highlighterEffect()
    propertyCount = effect?.numProperties
    for i in [1..propertyCount]
      property = effect.property(i)
      property.expression = ""

    @

NFHighlightLayer = Object.assign NFHighlightLayer,

  ###*
  Returns whether or not the given AVLayer is a valid Highlight Layer
  @memberof NFHighlightLayer
  @returns {boolean} whether the AV layer is a valid highlight layer
  ###
  isHighlightLayer: (theLayer) ->
    return theLayer instanceof ShapeLayer and theLayer.Effects.numProperties > 0 and theLayer.Effects.property("AV_Highlighter")?

  ###*
  Colors in the AV Highlighter Dropdown
  @memberof NFHighlightLayer
  ###
  COLOR:
    YELLOW:
      str: "Yellow"
      idx: 1
    BLUE:
      str: "Blue"
      idx: 2
    PURPLE:
      str: "Purple"
      idx: 3
    GREEN:
      str: "Green"
      idx: 4
    PINK:
      str: "Pink"
      idx: 5
    ORANGE:
      str: "Orange"
      idx: 6
    RED:
      str: "Red"
      idx: 7

  ###*
  Properties in the AV Highlighter effect
  @memberof NFHighlightLayer
  ###
  highlighterProperties: [
    'Spacing'
    'Thickness'
    'Start Offset'
    'Completion'
    'Offset'
    'Opacity'
    'Highlight Colour'
    'End Offset'
  ]
