###*
Creates a new NFLayerCollection from an array of [NFLayers]{@link NFLayer}
@class NFLayerCollection
@classdesc NF Wrapper object for a Array that contains NFLayers
@param {Array | LayerCollection | NFLayerCollection} layerArr - the array with [NFLayers]{@link NFLayer}
or an Adobe LayerCollection or an NFLayerCollection to initialize the collection with
@property {Array} layers - the array of [NFLayers]{@link NFLayer} in the collection
@throws Will throw an error if array contains non-{@link NFLayer} objects
###
class NFLayerCollection extends NFObject
  constructor: (layerArr) ->
    NFObject.call(this)
    @layers = layerArr ? []
    if layerArr?
      # Convert to an array if this is a LayerCollection or NFLayerCollection
      layerArr = layerArr.toArr() if layerArr instanceof LayerCollection
      layerArr = layerArr.layers if layerArr instanceof NFLayerCollection

      expectingAVLayers = no
      expectingNFLayers = no
      for theLayer in layerArr
        if theLayer.isAVLayer()
          throw new Error "You can't initialize NFLayerCollection with a mix of AVLayers and NFLayers" if expectingNFLayers
          expectingAVLayers = yes
        else if theLayer instanceof NFLayer
          throw new Error "You can't initialize NFLayerCollection with a mix of AVLayers and NFLayers" if expectingAVLayers
          expectingNFLayers = yes
        else
          throw new Error "You can only add NFLayers or AVLayers to an NFLayerCollection"


      newArray = for layer in layerArr
        if expectingAVLayers
          newLayer = new NFLayer(layer)
        else
          newLayer = layer
        newLayer.getSpecializedLayer()
      @layers = newArray
    @
  # MARK: Instance Methods
  toString: ->
    infoString = "NFLayerCollection: ["
    for theLayer in @layers
      infoString += theLayer.toString() + ", "
    infoString += "]"

  ###*
  Adds an NFLayer or AVLayer or NFLayerCollection to this collection. AVLayers will be added as
  specialized layers. Duplicates are ignored
  @memberof NFLayerCollection
  @param {NFLayer | AVLayer | NFLayerCollection} newLayer - the layer to add (or layer collection)
  @returns {NFLayerCollection} self
  ###
  add: (newLayer) ->
    return @ unless newLayer?
    if newLayer instanceof NFLayer
      @layers.push newLayer unless @containsLayer newLayer
    else if newLayer.isAVLayer?()
      layerToAdd = NFLayer.getSpecializedLayerFromAVLayer(newLayer)
      @layers.push layerToAdd unless @containsLayer layerToAdd
    else if newLayer instanceof NFLayerCollection
      newLayer.forEach (layer) =>
        @add layer
    else
      throw new Error "You can only add NFLayers or AVLayers to an NFLayerCollection"
    @

  ###*
  Returns the layer at the given index
  @memberof NFLayerCollection
  @param {int} idx - the layer index to access
  @returns {NFLayerCollection} self
  ###
  get: (idx) ->
    throw new Error "Index is out of bounds" if idx >= @count()
    return @layers[idx]

  ###*
  Iterates through each layer in the collection. The given function can take
  three parameters: layer, i, and layers. None of the parameters are required.
  IMPORTANT: Should be used with a fat arrow to call the callback function, so
  that scope is preserved. Don't add returns inside the function plz...
  @example
  myCollection.forEach (layer, i, layers) =>
    return "Layer number #{i} is called #{layer.getName()}"
  @memberof NFLayerCollection
  @param {function} fn - the function to use
  @returns {NFLayerCollection} self
  ###
  forEach: (fn) ->
    return null if @isEmpty()
    for i in [0..@count()-1]
      fn @layers[i], i, @layers
    @

  ###*
  Returns true if the collection only contains NFPageLayers and no other types of NFLayers
  @memberof NFLayerCollection
  @returns {boolean} if the layers in this collection are all {@link NFPageLayer} objects
  ###
  onlyContainsPageLayers: ->
    for theLayer in @layers
      return false unless theLayer instanceof NFPageLayer
    return true

  ###*
  Returns true if the given layer is in the collection
  @memberof NFLayerCollection
  @param {NFLayer} testLayer - the layer to check
  @returns {boolean} if the layer is in the collection
  ###
  containsLayer: (testLayer) ->
    for theLayer in @layers
      return true if theLayer.is testLayer
    return false

  ###*
  Sorts layers by index, from low to high
  @memberof NFLayerCollection
  @returns {NFLayerCollection} self
  ###
  sortByIndex: () ->
    return @ if @isEmpty()
    throw new Error "Can't sort if layers are from multiple comps" if not @inSameComp()

    orderedLayers = []
    for i in [0..@count()-1]
      topLayer = @getTopmostLayer()
      orderedLayers.push topLayer
      @remove topLayer

    @layers = orderedLayers

    return @

  ###*
  Returns true if the layers in the collection are all in the same comp
  @memberof NFLayerCollection
  @returns {boolean} if the layers in this collection are all in the same containing comp
  ###
  inSameComp: ->
    return true if @isEmpty()
    testID = @layers[0].containingComp().getID()
    for layer in @layers
      return false if layer.containingComp().getID() isnt testID
    return true

  ###*
  Returns the containing comp for the layers, or null if #inSameComp is false
  @memberof NFLayerCollection
  @returns {NFComp | null} the containing comp
  ###
  containingComp: ->
    if @inSameComp() and not @isEmpty()
      return @layers[0].containingComp()
    return null

  ###*
  Returns a new NFPageLayerCollection from this collection. Only call if you know
  this collection only contains NFPageLayers
  @memberof NFLayerCollection
  @returns {NFPageLayerCollection} the new collection
  ###
  getPageLayerCollection: ->
    return new NFPageLayerCollection @layers

  ###*
  Shortcut to access the number of layers in the collection
  @memberof NFLayerCollection
  @returns {int} the number of layers in the collection
  ###
  count: ->
    return @layers.length

  ###*
  True if the collection is empty
  @memberof NFLayerCollection
  @returns {boolean} whether or not the collection is empty
  ###
  isEmpty: ->
    return @count() is 0

  ###*
  Removes a given layer from this collection
  @memberof NFLayerCollection
  @returns {NFLayerCollection} self
  @param {NFLayer} layerToRemove the layer to be removed
  @throws Throws an error if the layers couldn't be found in this collection
  ###
  remove: (layerToRemove) ->
    # Get the index of the layer to remove
    for i in [0..@count()-1]
      layer = @layers[i]
      if layer.is layerToRemove
        @layers.splice(i, 1)
        return @
    throw new Error "Couldn't find layer to remove"

  ###*
  Returns a new NFLayerCollection of layers in this collection with names that
  include a search string
  @memberof NFLayerCollection
  @returns {NFLayerCollection} the collection of matching layers
  ###
  searchLayers: (searchString) ->
    return null if @isEmpty()
    matchingLayers = new NFLayerCollection
    for layer in @layers
      matchingLayers.add layer if layer.getName().indexOf(searchString) >= 0
    return matchingLayers

  ###*
  Gets the topmost NFLayer in this collection
  @memberof NFLayerCollection
  @returns {NFLayer | null} the topmost layer or null if empty
  @throws Throws an error if the layers are in different comps
  ###
  getTopmostLayer: ->
    return null if @isEmpty()
    throw new Error "Can't get topmost layer of layers in different comps" unless @inSameComp()
    topmostLayer = @layers[0]
    for layer in @layers
      topmostLayer = layer if layer.$.index < topmostLayer.$.index
    return topmostLayer

  ###*
  Gets the bottommost NFLayer in this collection
  @memberof NFLayerCollection
  @returns {NFLayer | null} the bottommost layer or null if empty
  @throws Throws an error if the layers are in different comps
  ###
  getBottommostLayer: ->
    return null if @isEmpty()
    throw new Error "Can't get bottommost layer of layers in different comps" unless @inSameComp()
    bottommostLayer = @layers[0]
    for layer in @layers
      bottommostLayer = layer if layer.$.index > bottommostLayer.$.index
    return bottommostLayer

  ###*
  Sets all member layers' parents to a given {@link NFLayer} or null
  @memberof NFLayerCollection
  @param {NFLayer | null} newParent - the new parent for the member layers
  @returns {NFLayerCollection} self
  ###
  setParents: (newParent) ->
    unless @isEmpty()
      for layer in @layers
        layer.setParent(newParent)
    return @

  ###*
  Creates a new null parent to all the layers in the collection, positioned above the one with the lowest index. Will override previous parenting.
  @memberof NFLayerCollection
  @returns {NFLayer} the new null NFLayer
  ###
  nullify: ->
    throw new Error "Cannot nullify layers in different compositions at the same time" unless @inSameComp()
    throw new Error "Cannot nullify without a given layer" if @isEmpty()
    newNull = @containingComp().addNull()
    @setParents(newNull)
    topLayer = @getTopmostLayer()
    newNull.moveBefore topLayer
    return newNull

  ###*
  Gets the earliest appearing NFLayer in this collection
  @memberof NFLayerCollection
  @returns {NFLayer | null} the topmost layer or null if empty
  @throws Throws an error if the layers are in different comps
  ###
  getEarliestLayer: ->
    return null if @isEmpty()
    throw new Error "Can't get earliest layer of layers in different comps" unless @inSameComp()
    earliestLayer = @layers[0]
    for layer in @layers
      earliestLayer = layer if layer.$.inPoint < earliestLayer.$.inPoint
    return earliestLayer

  ###*
  Gets the latest appearing NFLayer in this collection. Only returns one layer
  even if two layers have the same outPoint
  @memberof NFLayerCollection
  @returns {NFLayer | null} the topmost layer or null if empty
  @throws Throws an error if the layers are in different comps
  ###
  getLatestLayer: ->
    return null if @isEmpty()
    throw new Error "Can't get latest layer of layers in different comps" unless @inSameComp()
    latestLayer = @layers[0]
    for layer in @layers
      latestLayer = layer if layer.$.outPoint > latestLayer.$.outPoint
    return earliestLayer
