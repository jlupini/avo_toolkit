###*
Creates a new NFComp and sets its comp property.
@class NFComp
@classdesc NF Wrapper object for a CompItem that allows for access to and maniplation of its layers.
@property {CompItem} $ - the CompItem for this NFComp
@param {CompItem | NFComp} comp - the CompItem for this NFComp
@throws Will throw an error if not given a valid CompItem at initialization
###
class NFComp extends NFObject
  constructor: (comp) ->
    NFObject.call(this)
    if comp instanceof CompItem
      item = comp
    else if comp instanceof NFComp
      item = comp.comp
    else
      throw new Error "Cannot create an NFComp without a valid CompItem or NFComp"
    @$ = item
    @
  toString: ->
    return "NFComp: '#{@getName()}'"

  ###*
  Provides an object to be easily converted to JSON for the CEP Panel
  @memberof NFComp
  @returns {Object} the CEP Panel object
  ###
  simplify: ->
    obj =
      class: "NFComp"
      name: @getName()
      id: @getID()
      numLayers: @$.numLayers
    return obj

  ###*
  Returns the aeq.Comp object
  @memberof NFComp
  @returns {aeq.Comp} the aequery comp
  ###
  aeq: ->
    return new aeq.Comp @$

  ###*
  Gets the comp's name
  @memberof NFComp
  @returns {String} The comp's name
  ###
  getName: ->
    return @$.name

  ###*
  Gets the comp's rect
  @memberof NFComp
  @returns {Rect} The comp's rect
  ###
  getRect: ->
    return new Rect
      left: 0
      top: 0
      width: @$.width
      height: @$.height

  ###*
  Gets the comp's unique ID
  @memberof NFComp
  @returns {String} The comp's ID
  ###
  getID: ->
    return @$.id

  ###*
  Checks to see if two NFComps have the same ID
  @memberof NFComp
  @param {NFComp} testComp - the comp to compare
  @returns {boolean} if they're referrring to the same object
  @throws Throws error if testComp is not an NFComp or subclass
  ###
  is: (testComp) ->
    throw new Error "Can't compare an NFComp to a different type of object" unless testComp instanceof NFComp
    return @getID() is testComp.getID()

  ###*
  Gets the selected layers in this comp
  @memberof NFComp
  @returns {NFLayerCollection} collection of the selected layers in the comp
  ###
  selectedLayers: ->
    return new NFLayerCollection @$.selectedLayers

  ###*
  Gets all the layers in this comp
  @memberof NFComp
  @returns {NFLayerCollection} collection of the layers in the comp
  ###
  allLayers: ->
    return new NFLayerCollection @$.layers

  ###*
  Gets all the audio layers in this comp
  @memberof NFComp
  @returns {NFLayerCollection} collection of the audio layers in the comp
  ###
  audioLayers: ->
    audioLayers = new NFLayerCollection
    @allLayers().forEach (layer) =>
      audioLayers.add layer if layer.$.hasAudio and not layer.$.hasVideo
    return audioLayers

  ###*
  Gets the selected pages in this comp
  @memberof NFComp
  @returns {NFPageLayerCollection} collection of the selected NFPageLayers in the comp
  ###
  selectedPageLayers: ->
    selectedPageLayers = new NFPageLayerCollection
    @selectedLayers().forEach (layer) =>
      selectedPageLayers.add(layer) if layer instanceof NFPageLayer
    return selectedPageLayers

  ###*
  Returns the greenscreen footage layer, or null if not found
  @memberof NFComp
  @returns {NFLayer | null} The greenscreen layer or null
  ###
  greenscreenLayer: ->
    matchedLayers = @searchLayers "greenscreen", no

    if matchedLayers.count() is 1
      return matchedLayers.get 0
    else
      return null

  ###*
  Gets the active NFLayers at a time (or current time by default).
  @memberof NFComp
  @param {float} [time] - the time to check at, or the current time by default
  @returns {NFLayerCollection} The active layers or null if none active
  ###
  activeLayers: (time) ->
    # Set the current time to the test time, but we'll need to set it back later.
    if time?
      originalTime = @getTime()
      @setTime(time)

    activeLayers = new NFLayerCollection
    @allLayers().forEach (layer) =>
      activeLayers.add layer if layer.isActive()

    @setTime originalTime if originalTime?
    return activeLayers

  ###*
  # Returns the first NFLayer in this comp with the layer name given or null
  # if none found. Use #layersWithName if there's the possibility of multiple
  # layers with the given name.
  # @memberof NFComp
  # @param {string} name - The search layer's name
  # @returns {NFLayer|null} The found layer or null
  ###
  layerWithName: (name) ->
    theLayer = @$.layers?.byName(name)
    if theLayer?
      foundLayer = new NFLayer(theLayer)
      return foundLayer.getSpecializedLayer()
    return null

  ###*
  # Returns an NFLayerCollection with the NFLayers in this comp with the layer
  # name given or null if none found
  # @memberof NFComp
  # @param {string} name - The search layer's name
  # @returns {NFLayerCollection} The found layers
  ###
  layersWithName: (name) ->
    foundLayers = new NFLayerCollection
    @allLayers().forEach (layer) =>
      foundLayers.add layer if layer.getName() is name
    return foundLayers

  ###*
  # Returns an NFLayerCollection with the NFLayers in this comp that contain
  # the searchString in their name
  # @memberof NFComp
  # @param {string} searchString - The search string
  # @param {boolean} [caseSensitive=yes] - whether to match case
  # @param {String} [exclude=null] - if this text is found in the name, do not return the layer in the collection
  # @returns {NFLayerCollection} The found layers
  ###
  searchLayers: (searchString, caseSensitive = yes, exclude = null) ->
    foundLayers = new NFLayerCollection
    searchString = searchString.toLowerCase() unless caseSensitive
    @allLayers().forEach (layer) =>
      matchName = layer.getName()
      matchName = matchName.toLowerCase() unless caseSensitive
      if matchName.indexOf(searchString) >= 0
        unless exclude? and matchName.indexOf(exclude) >= 0
          foundLayers.add layer
    return foundLayers

  ###*
  Sets the comp time
  @memberof NFComp
  @param {float} newTime - the new time
  @returns {NFComp} self
  ###
  setTime: (newTime) ->
    @$.time = newTime
    @

  ###*
  Gets the comp time
  @memberof NFComp
  @returns {float} the time
  ###
  getTime: (newTime) ->
    return @$.time

  ###*
  Gets the center point of the comp
  @memberof NFComp
  @returns {Point} the center point
  ###
  centerPoint: ->
    return [@$.width / 2, @$.height / 2]

  ###*
  # Creates and returns a new null layer in this comp
  # @memberof NFComp
  # @param {String} [name] - the name for the null
  # @param {Point} [position] - the position of the null in the comp's coordinate system
  # @returns {NFLayer} The newly created null layer
  ###
  addNull: (name = null, position = null) ->
    newNull = new NFLayer @$.layers.addNull()

    newNull.transform("Position").setValue position if position?
    newNull.setName name if name?

    return newNull

  ###*
  Creates and returns a new solid layer in this comp
  @memberof NFComp
  @param {Object} model
  @param {float[]} model.color - the solid color. Three-value array of floats
  from 0.0-1.0 in the form [R, G, B]
  @param {String} [model.name="New Solid"] - the solid name.
  @param {float} [model.width=compWidth] - the width
  @param {float} [model.height=compHeight] - the height
  @returns {NFLayer} The newly created solid layer
  ###
  addSolid: (model) ->
    model =
      color: model.color ? throw new Error "Solids need a color"
      name: model.name ? "New Solid"
      width: model.width ? @$.width
      height: model.height ? @$.height
    solidAVLayer = @$.layers.addSolid(model.color, model.name, model.width, model.height, 1)
    return NFLayer.getSpecializedLayerFromAVLayer solidAVLayer


  ###*
  Creates and returns a new shape layer with a rectangle in the comp
  @memberof NFComp
  @returns {NFShapeLayer} The newly created shape layer
  ###
  addShapeLayer: ->
    shapeAVLayer = @$.layers.addShape()
    shapeLayer = NFLayer.getSpecializedLayerFromAVLayer shapeAVLayer
    shapeLayer.transform("Position").setValue([0,0])
    return shapeLayer

  ###*
  Given a shape layer and number of lines, creates a new NFHighlightLayer
  highlight.
  @memberof NFComp
  @param {Object} model
  @param {NFLayer} model.shapeLayer the shape layer with target shape
  @param {String} [model.name="OLD_NAME Highlight"] the new name
  @param {int} model.lines the number of lines
  @param {Object} [model.color=NFHighlightLayer.COLOR.YELLOW] the color from the available dropdown colors
  @returns {NFHighlightLayer} the new highlight
  ###
  createHighlight: (model) ->
    model =
      shapeLayer: model.shapeLayer ? throw new Error "Must specify a shape layer"
      lines: model.lines ? throw new Error "Must include number of lines"
      name: model.name ? "#{model.shapeLayer.getName()} Highlight"
      color: model.color ? NFHighlightLayer.COLOR.YELLOW
      rectHash: model.rectHash ? null
    throw new Error "model.shapeLayer must be a valid shape layer" unless model.shapeLayer.isShapeLayer()

    # First, let's get the source rect
    currTime = @getTime()
    rect = model.shapeLayer.sourceRect()
    @setTime currTime

    # Determine line height and paddings
    lineHeight = rect.height / model.lines
    xPadding = lineHeight / 5
    yPadding = lineHeight / 7 / model.lines
    paddedLineHeight = lineHeight + yPadding

    # Boom done. Now we'll make a new Shape Layer and Build the Highlight
    highlightLayer = new NFLayer @$.layers.addShape()
    highlightLayer.setName model.name
    highlightLayer.transform().property("Position").setValue [0,0]
    highlightLayer.transform().property("Position").expression = '[transform.position[0]+ effect("AV Highlighter")("Offset")[0], transform.position[1]+ effect("AV Highlighter")("Offset")[1]]'
    highlightLayer.$.blendingMode = BlendingMode.MULTIPLY

    # Setup AV Highlighter
    highlightProperty = highlightLayer.addEffect('AV_Highlighter')
    highlightProperty.property("Spacing").setValue paddedLineHeight
    highlightProperty.property("Thickness").setValue paddedLineHeight + 0.25
    yOffset = if model.lines is 1 then paddedLineHeight / 2 - yPadding else paddedLineHeight / 2 - yPadding * 2
    highlightProperty.property("Offset").setValue [0, yOffset]
    highlightProperty.property("Highlight Colour").setValue model.color.idx

    highlightLayer.transform().property('Opacity').expression = 'effect("AV Highlighter")("Opacity")'

    # Add a point Control for the rect hash if it exists
    if model.rectHash?
      hashProp = highlightLayer.addEffect('ADBE Point Control')
      hashProp.property("Point").setValue model.rectHash
      hashProp.name = "Rect Hash"

    # Add a split point Control
    # FIXME: This duplicates functionality in NFHighlightLayer - get rid of it here
    splitProp = highlightLayer.addEffect('ADBE Point Control')
    splitProp.property("Point").setValue [0,0]
    splitProp.name = "Split Point"

    # Build the Lines
    mainContents = highlightLayer.property("ADBE Root Vectors Group")

    lineShape = new Shape()
    lineShape.vertices = [
      [rect.left - xPadding, rect.top],
      [rect.left + rect.width + xPadding, rect.top]
    ]
    lineShape.inTangents = []
    lineShape.outTangents = []
    lineShape.closed = no

    # Add Group
    group = mainContents.addProperty("ADBE Vector Group")
    group.name = "Highlight Lines"
    for i in [1..model.lines]
      lineGroup = group.property("Contents").addProperty("ADBE Vector Group")
      lineGroup.name = "Line #{i}"
      lineGroup.property('Transform').property('Position').expression = '[0, effect("AV Highlighter")("Spacing")*' + (i - 1) + ']'
      linePathProp = lineGroup.property("Contents").addProperty("ADBE Vector Shape - Group")
      linePathProp.name = "Line #{i} Path"
      linePathProp.property("ADBE Vector Shape").setValue(lineShape)
      lineTrimProp = lineGroup.property("Contents").addProperty('ADBE Vector Filter - Trim')
      lineTrimProp.property('Start').expression = 'effect("AV Highlighter")("Start Offset")' if i is 1
      lineTrimProp.property('End').expression = NFTools.readExpression "highlight-trim-end-expression",
        LINE_COUNT: model.lines
        THIS_LINE: i
      lineStrokeProp = lineGroup.property("Contents").addProperty("ADBE Vector Graphic - Stroke")

      lineStrokeProp.property("Color").expression = NFTools.readExpression "highlight-stroke-color-expression"
      lineStrokeProp.property('Stroke Width').expression = 'effect("AV Highlighter")("Thickness")'


    return null

  ###*
  Creates and returns a new text layer in this comp
  @memberof NFComp
  @param {Object} model
  @param {String} [model.text=""]
  @param {float} [model.time=currTime] - the start time of the layer
  @param {float} [model.duration=remainderOfComp] - the duration of the layer
  @param {NFLayer} [model.below] - the layer to put this layer below
  @param {NFLayer} [model.above] - the layer to put this layer above
  @param {int} [model.at=0] - the index to put this layer
  @param {boolean} [model.applyFill=yes]
  @param {boolean} [model.applyStroke=no]
  @param {float} [model.fontSize=24]
  @param {float[]} [model.fillColor=[0,0,0]]
  @param {float[]} [model.strokeColor=[1,1,1]]
  @param {ParagraphJustification} [model.justification=ParagraphJustification.LEFT_JUSTIFY]
  @param {String} [model.font="Avenir Next"]
  @param {float} [model.tracking=0]
  @returns {NFLayer} The newly created text layer
  ###
  addTextLayer: (model) ->
    model.time ?= @getTime()
    model =
      time: model.time
      duration: model.duration ? @$.duration - model.time
      below: model.below
      above: model.above
      at: model.at
      applyFill: model.applyFill ? yes
      applyStroke: model.applyStroke ? no
      strokeWidth: model.strokeWidth ? 2
      strokeOverFill: model.strokeOverFill ? false
      fontSize: model.fontSize ? 24
      text: model.text ? ""
      fillColor: model.fillColor ? [0,0,0]
      strokeColor: model.strokeColor ? [1,1,1]
      justification: model.justification ? ParagraphJustification.LEFT_JUSTIFY
      font: model.font ? 'Avenir Next'
      tracking: model.tracking ? 0

    throw new Error "model.above must be an NFLayer" if model.above? and not model.above instanceof NFLayer
    throw new Error "model.below must be an NFLayer" if model.below? and not model.below instanceof NFLayer
    index = 0
    tooManyIndices = no
    if model.above? and model.above instanceof NFLayer
      tooManyIndices = yes if model.below? or model.at?
      if model.above.containingComp().is @
        index = model.above.index() - 1
      else
        throw new Error "Cannot insert layer above a layer not in this comp"
    else if model.below? and model.below instanceof NFLayer
      tooManyIndices = yes if model.above? or model.at?
      if model.below.containingComp().is @
        index = model.below.index()
      else
        throw new Error "Cannot insert layer below a layer not in this comp"
    else if model.at?
      tooManyIndices = yes if model.above? or model.below?
      index = model.at
    throw new Error "Can only provide one of .above, .below, or .at when inserting text layer" if tooManyIndices


    textAVLayer = @$.layers.addText new TextDocument model.text
    textDocProp = textAVLayer.property("ADBE Text Properties").property("ADBE Text Document")
    textDoc = textDocProp.value

    textDoc.applyFill = model.applyFill
    textDoc.fillColor = model.fillColor
    textDoc.applyStroke = model.applyStroke
    textDoc.strokeWidth = model.strokeWidth
    textDoc.strokeOverFill = model.strokeOverFill
    textDoc.strokeColor = model.strokeColor
    textDoc.font = model.font
    textDoc.fontSize = model.fontSize
    textDoc.justification = model.justification
    textDoc.tracking = model.tracking

    textDocProp.setValue textDoc

    textAVLayer.moveBefore @$.layers[index+2] unless index is 0
    textAVLayer.startTime = model.time


    return new NFLayer textAVLayer

  ###*
  Inserts a layer into the comp at a given index at the current time. Returns
  the new layer
  @memberof NFComp
  @returns {NFLayer} the new layer
  @param {Object} model - the parameters
  @param {NFComp} model.comp - the comp to insert
  @param {NFLayer} [model.above] - the layer to insert the page above. Can use
  only one of .above, .below or .at
  @param {NFLayer} [model.below] - the layer to insert the page below. Can use
  only one of .above, .below or .at
  @param {int} [model.at=0] - the index to insert the page at. Can use only
  one of .above, .below or .at
  @param {float} [model.time=Current Time] - the time to insert the comp at
  @throws Throw error if given values for more than one of .above, .below,
  and .at
  ###
  insertComp: (model) ->
    throw new Error "No comp to insert" unless model.comp? and model.comp instanceof NFComp
    throw new Error "model.above must be an NFLayer" if model.above? and not model.above instanceof NFLayer
    throw new Error "model.below must be an NFLayer" if model.below? and not model.below instanceof NFLayer
    index = 0
    tooManyIndices = no
    if model.above? and model.above instanceof NFLayer
      tooManyIndices = yes if model.below? or model.at?
      if model.above.containingComp().is @
        index = model.above.index() - 1
      else
        throw new Error "Cannot insert layer above a layer not in this comp"
    else if model.below? and model.below instanceof NFLayer
      tooManyIndices = yes if model.above? or model.at?
      if model.below.containingComp().is @
        index = model.below.index()
      else
        throw new Error "Cannot insert layer below a layer not in this comp"
    else if model.at?
      tooManyIndices = yes if model.above? or model.below?
      index = model.at

    throw new Error "Can only provide one of .above, .below, or .at when inserting page" if tooManyIndices

    # Gonna do some work with AV Layers
    newAVLayer = @$.layers.add(model.comp.$)
    newAVLayer.startTime = model.time ? @getTime()
    # Note: we're doing moveBefore with index + 2 to account for both
    #       the new layer that's been added AND the obnoxious 1-indexing
    #       of adobe's LayerCollections
    unless index is 0
      if index + 1 is @$.layers.length
        newAVLayer.moveAfter @$.layers[index+1]
      else
        newAVLayer.moveBefore @$.layers[index+2]

    # Convert back to an NFLayer for the return
    return NFLayer.getSpecializedLayerFromAVLayer newAVLayer

# Class Methods
NFComp = Object.assign NFComp,

  ###*
  # Returns a new NFComp, or a NFPartComp or NFPageComp if suitable
  # @memberof NFComp
  # @param {NFComp | CompItem}
  # @returns {NFComp | NFPageComp | NFPartComp} The new comp
  ###
  specializedComp: (comp) ->
    compItem = if comp instanceof CompItem then comp else comp.$
    if NFPageComp.canBePageComp compItem
      return new NFPageComp comp
    else if NFPartComp.canBePartComp compItem
      return new NFPartComp comp

    return new NFComp comp

  TOP: 100
  LEFT: 200
  BOTTOM: 300
  RIGHT: 400
  AUTO: 500
