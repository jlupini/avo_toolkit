###*
Creates a new NFGaussyLayer from a given AVLayer
@class NFGaussyLayer
@classdesc Subclass of {@link NFLayer} for a gaussy layer
@param {AVLayer | NFLayer} layer - the target AVLayer or NFLayer
@property {AVLayer} layer - the wrapped AVLayer
@extends NFLayer
###
class NFGaussyLayer extends NFLayer
  constructor: (layer) ->
    NFLayer.call(this, layer)
    @
  toString: ->
    return "NFGaussyLayer: '#{@$.name}'"

  ###*
  Provides an object to be easily converted to JSON for the CEP Panel
  @memberof NFGaussyLayer
  @returns {Object} the CEP Panel object
  ###
  simplify: ->
    obj = NFLayer.prototype.simplify.call @
    obj.class = "NFGaussyLayer"
    return obj

NFGaussyLayer = Object.assign NFGaussyLayer,

  ###*
  Returns whether or not the given AVLayer is a valid Gaussy Layer
  @memberof NFGaussyLayer
  @param {AVLayer} the layer to check
  @returns {boolean} whether the AV layer is a valid gaussy layer
  ###
  isGaussyLayer: (theLayer) ->
    return theLayer.name.indexOf("Gaussy") >= 0

  ###*
  Creates a new NFGaussyLayer above the spotlight on the given group
  @memberof NFGaussyLayer
  @param {Object} model
  @param {NFLayer} model.group - DEPRECATED. USE model.layer INSTEAD
  @param {NFLayer} model.layer - the layer under which to create the gaussy layer
  @param {float} [model.time=currTime] - the time to start the effect at
  @param {float} [model.duration=5.0] - the length of the effect
  @returns {NFGaussyLayer} the new gaussy layer
  ###
  newGaussyLayer: (model) ->
    if model.group?
      model.layer = model.group
    model =
      layer: model.layer ? throw new Error "Gaussy layers need a target layer"
      time: model.time ? model.layer.containingComp().getTime()
      duration: model.duration ? 5

    NFTools.log "Creating new Gaussy layer on #{model.layer.toString()}", "static NFGaussyLayer"

    newName = NFGaussyLayer.nameFor model.layer
    gaussyLayer = model.layer.containingComp().addSolid
      color: [0.45, 0.93, 0.89]
      name: newName
    gaussyAVLayer = gaussyLayer.$

    gaussyAVLayer.adjustmentLayer = true

    # Eventually kill this
    if model.group?
      spotlightLayer = model.group.getSpotlight()
      if spotlightLayer?
        gaussyLayer.moveBefore spotlightLayer
      else
        gaussyLayer.moveAfter model.group.getCitationLayer()
    else
      gaussyLayer.moveAfter model.layer

    gaussyAVLayer.startTime = model.time
    gaussyAVLayer.outPoint = model.time + model.duration

    effects = gaussyLayer.effects()
    gaussyEffect = effects.addProperty "AV_Gaussy"
    gaussyEffect.property("Duration").setValue 60

    gaussianBlur = effects.addProperty('Gaussian Blur')
    gaussianBlur.property('Repeat Edge Pixels').setValue true
    sourceExpression = NFTools.readExpression "gaussy-blur-expression"
    gaussyLayer.effect('Gaussian Blur').property('Blurriness').expression = sourceExpression

    # Add Desaturation/Lightness
    hueSatEffect = effects.addProperty "ADBE Color Balance (HLS)"
    masterSaturation = hueSatEffect.property("Saturation")
    masterLightness = hueSatEffect.property("Lightness")
    masterSaturation.expression = NFTools.readExpression "gaussy-saturation-expression"
    masterLightness.expression = NFTools.readExpression "gaussy-lightness-expression"

    return gaussyLayer

  ###*
  Returns the name a new gaussy layer should have. Gaussy layers affect all
  layers below them, so they're not named based on the layer they target.
  Instead, they're just named sequentially within the comp they reside in.
  @memberof NFGaussyLayer
  @param {NFPaperLayerGroup} group - the group
  @returns {String} the citation layer/comp name
  ###
  nameFor: (group) ->
    comp = group.containingComp()
    existingGaussies = comp.searchLayers "Gaussy"

    return "Gaussy - ##{existingGaussies.count() + 1}"
