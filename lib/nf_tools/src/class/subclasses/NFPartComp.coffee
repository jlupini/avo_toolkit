###*
Creates a new NFPartComp and sets its comp property.
@class NFPartComp
@classdesc NF Wrapper object for a CompItem used as a part comp that allows for access to and maniplation of its layers.
@property {CompItem} comp - the CompItem for this NFPartComp
@param {CompItem} comp - the CompItem for this NFPartComp
@extends NFComp
@throws Will throw an error if not given a valid CompItem at initialization
###
class NFPartComp extends NFComp
  constructor: (comp) ->
    NFComp.call(this, comp)
    throw new Error "Can't create an NFPartComp from a non-part comp" unless NFPartComp.canBePartComp(@$)
    @

  toString: ->
    return "NFPartComp: '#{@getName()}'"

  ###*
  Provides an object to be easily converted to JSON for the CEP Panel
  @memberof NFPartComp
  @returns {Object} the CEP Panel object
  ###
  simplify: ->
    obj = NFComp.prototype.simplify.call @
    obj.class = "NFPartComp"
    return obj

  ###*
  Animates to a given highlight or page, with options. Will throw an error if
  there are
  other animations that take place after the current time on the same PDF in
  this comp. Must include one of model.highlight or model.page
  @memberof NFPartComp
  @param {Object} model - the model object
  @param {NFHighlightLayer} [model.highlight] - the highlight to animate to
  @param {NFPageComp} [model.page] - the page to animate to
  @param {time} [model.time=currTime] - the time to do the animation at
  @param {float} [model.animationDuration=3] - the length of the move and scale
  @param {float} [model.pageTurnDuration=2] - the length of the pageturn
  @param {float} [model.maxPageScale=115] - the maximum a page will scale
  @param {float} [model.fillPercentage=85] - the percentage of the comp width
  for the final highlight to take up
  @param {boolean} [model.skipTitle=false] - whether we should skip going to the
  title page if this PDF is new in the project
  @throws Throw error if not given a highlight
  @throws Throw error if there is movement on the target page parent layer
  after the current comp time in this comp.
  @returns {NFPageLayer|NFHighlightLayer} model.page or model.highlight
  ###
  animateTo: (model) ->
    model =
      highlight: model.highlight
      page: model.page
      time: model.time
      animationDuration: model.animationDuration ? 3
      pageTurnDuration: model.pageTurnDuration ? 2
      maxPageScale: model.maxPageScale ? 115
      skipTitle: model.skipTitle ? no
      fillPercentage: model.fillPercentage ? 85

    unless model.highlight? or model.page?
      throw new Error "No highlight or page to animate to"
    if model.highlight? and model.page?
      throw new Error "Cannot animate to both a page and highlight."

    if model.page?
      throw new Error "Page is of wrong type" unless model.page instanceof NFPageComp
      targetPDF = model.page.getPDF()
    else if model.highlight?
      throw new Error "Highlight is of wrong type" unless model.highlight instanceof NFHighlightLayer
      targetPDF = model.highlight.getPDF()

    containingPartComps = targetPDF.containingPartComps()
    targetPage = model.page ? model.highlight.getPageComp()
    preAnimationTime = @getTime()
    @setTime model.time if model.time?
    activePDF = @activePDF()
    prevGroup = @groupFromPDF activePDF if activePDF?

    # If we've NEVER SEEN THIS PDF before
    if containingPartComps.length is 0
      # Get the active page, if any
      activePageLayer = @activePage()

      #  If we don't have the 'no q' flag
      if model.skipTitle is no
        # Bring in the motherfucking title page, initialize it
        titlePage = targetPDF.getTitlePage()
        titlePageLayer = @insertPage
          page: titlePage
          animate: yes

        trimTime = titlePageLayer.getInMarkerTime()
        prevGroup.trim trimTime if prevGroup?
        @hideGaussy trimTime + 1

        group = new NFPaperLayerGroup titlePageLayer.getPaperParentLayer()
        group.getCitationLayer().show @getTime()+0.5

        # If the target is a highlight, keep working...
        if model.highlight?
          # If the highlight we want is on the title page
          if targetPage.is titlePage
            # Move the time to the in marker and run moveTo
            @setTime titlePageLayer.getInMarkerTime()
            group.assignControlLayer model.highlight, @getTime() - 0.5

            group.moveTo
              highlight: model.highlight
              duration: model.animationDuration
              maxScale: model.maxPageScale
              fillPercentage: model.fillPercentage

          # Else (it's on a different page)
          else
            @setTime(titlePageLayer.getInMarkerTime() - 0.4)
            # Bring that page in below the title page layer
            targetPageLayer = @insertPage
              page: targetPage
              below: titlePageLayer
              frameUp:
                highlight: model.highlight
                fillPercentage: model.fillPercentage * 0.7

            if model.highlight?
              group.assignControlLayer model.highlight, titlePageLayer.getInMarkerTime() + 0.5

            titlePageLayer.animatePageTurn()

            if model.highlight?
              group.moveTo
                highlight: model.highlight
                duration: model.animationDuration
                fillPercentage: model.fillPercentage
                maxScale: model.maxPageScale

      #  else (we've been passed the 'no q' flag)
      else
        targetPageLayer = @insertPage
          page: targetPage
          animate: yes
          frameUp:
            highlight: model.highlight
            fillPercentage: model.fillPercentage

        group = new NFPaperLayerGroup targetPageLayer.getPaperParentLayer()
        group.getCitationLayer().show @getTime()+0.5

        # Trim the old layer to the end of the page turn
        trimTime = targetPageLayer.getInMarkerTime()
        prevGroup.trim trimTime if prevGroup?
        @hideGaussy trimTime + 1

        if model.highlight?
          group.assignControlLayer model.highlight, @getTime() + 0.25

    # else (this pdf is in a part comp somewhere)
    else
      # Ensure there are no keyframes on the target's parent in the future
      targetGroup = @groupFromPDF targetPDF
      if targetGroup?
        posProp = targetGroup.paperParent.transform().position
        latestKeyTime = posProp.keyTime posProp.numKeys if posProp.numKeys > 0
        if latestKeyTime?
          if latestKeyTime > @getTime() + 2.0
            throw new Error "Can't animate to page or highlight because animations exist in the FUTURE on the target PDF"
          else if latestKeyTime > @getTime()
            @log "WARNING: This instruction is too close to the previous one, so we're bumping it forward up to two seconds."
            @setTime latestKeyTime + 0.1

      # If it's the active PDF now
      if @activePDF()?.is targetPDF
        activePageLayer = @activePage()
        group = new NFPaperLayerGroup activePageLayer.getPaperParentLayer()

        # if the target page is the visible page
        if targetPage.is activePageLayer.getPageComp()
          # RUN AS NORMAL, but move to a the title rect if not given a highlight
          group.moveTo
            highlight: model.highlight ? null
            rect: if model.highlight? then null else activePageLayer.sourceRectForFullTop()
            layer: if model.highlight? then null else activePageLayer
            duration: model.animationDuration
            fillPercentage: if model.highlight? then model.fillPercentage else 100
            maxScale: model.maxPageScale

          # Trim any active spotlights and placeholders
          group.trimActivePlaceholder @getTime()
          group.trimActiveSpotlights @getTime() + (model.animationDuration / 2)
          # FIXME: This should be El Sneako!
          @hideGaussy @getTime()

          if model.highlight?
            group.assignControlLayer model.highlight, @getTime() + (model.animationDuration / 2)
            model.highlight.getControlLayer().setSpotlightMarkerInPoint @getTime() + (model.animationDuration / 2)


        # else (the highlight is on a different page)
        else

          # If the target page was used in this part and it was above the currently active layer
          # or if we're going to the title page
          layersForPage = @layersForPage targetPage
          isUsedInPartAboveCurrentLayer = layersForPage.count() > 0 and layersForPage.layers[0].index() < activePageLayer.index()
          isTitlePage = targetPDF.getTitlePage().getPageNumber() is targetPage.getPageNumber()
          if isUsedInPartAboveCurrentLayer or isTitlePage

              # Add the page layer above this current one, but peeled up.
              # Also frame it up
              targetPageLayer = @insertPage
                page: targetPage
                above: activePageLayer
                time: @getTime() - 0.5
                pageTurn: NFPageLayer.PAGETURN_FLIPPED_UP
                continuous: yes
                frameUp:
                  highlight: model.highlight
                  fillPercentage: model.fillPercentage * 2

              # Run a page turn flip down starting half a second back from now
              pageTurnDuration = 2.0
              targetPageLayer.animatePageTurn
                time: @getTime() - 0.5
                duration: pageTurnDuration

              # Move the whole shabang to frame up the target highlight
              if model.highlight?
                group.moveTo
                  highlight: model.highlight
                  duration: model.animationDuration
                  fillPercentage: model.fillPercentage

              # Trim the old layer to the end of the page turn
              activePageLayer.$.outPoint = @getTime() - 0.5 + 2.0

              group.trimActivePlaceholder @getTime()
              group.trimActiveSpotlights @getTime() + 0.5
              # FIXME: This should be El Sneako!
              @hideGaussy @getTime()

              if model.highlight?
                group.assignControlLayer model.highlight, @getTime() + 0.5
                model.highlight.getControlLayer().setSpotlightMarkerInPoint @getTime() + 0.5

          # else (we haven't seen it in this part or it was below)
          else
            # Add the page layer below this current one.
            # Also frame it up
            targetPageLayer = @insertPage
              page: targetPage
              below: activePageLayer
              time: @getTime() - 0.5
              continuous: yes
              frameUp:
                highlight: model.highlight
                fillPercentage: model.fillPercentage * 0.7

            # Run a page turn flip down starting half a second back from now
            activePageLayer.animatePageTurn
              time: @getTime() - 0.5
              duration: 2.0

            # Move the whole shabang to frame up the target highlight
            if model.highlight?
              group.moveTo
                highlight: model.highlight
                duration: model.animationDuration
                fillPercentage: model.fillPercentage

            group.trimActivePlaceholder @getTime()
            group.trimActiveSpotlights @getTime() + 0.5
            # FIXME: This should be El Sneako!
            @hideGaussy @getTime()

            if model.highlight?
              group.assignControlLayer model.highlight, @getTime() + 0.5
              model.highlight.getControlLayer().setSpotlightMarkerInPoint @getTime() + 0.5

      # else (not the active PDF)
      else
        # Animate in the page ALREADY focused on the highlight or page
        activePageLayer = @activePage()
        targetGroup = @groupFromPDF targetPDF
        activePDF = @activePDF()
        prevGroup = @groupFromPDF activePDF if activePDF?
        alreadyInThisPart = targetGroup?

        targetPageLayer = @insertPage
          page: targetPage
          continuous: yes
          frameUp:
            highlight: model.highlight
            fillPercentage: model.fillPercentage

        targetGroup = @groupFromPDF targetPDF
        targetGroup.getCitationLayer().show @getTime()+0.5

        if alreadyInThisPart
          targetGroup.gatherLayers new NFLayerCollection [targetPageLayer]

          # If it's above, the active layer, slide it in
          # Otherwise, slide the active layer out
          if targetPageLayer.index() < activePageLayer.index()
            targetPageLayer.slideIn()
            trimTime = targetPageLayer.getInMarkerTime()
            prevGroup?.trim trimTime
            @hideGaussy trimTime + 1
          else
            trimTime = targetPageLayer.$.inPoint + 2.0
            prevGroup?.trim trimTime
            @hideGaussy @getTime()
            activePageLayer.slideOut()
        else
          targetPageLayer.slideIn()
          trimTime = targetPageLayer.getInMarkerTime()
          prevGroup?.trim trimTime
          @hideGaussy trimTime + 1

        if model.highlight?
          targetGroup.assignControlLayer model.highlight, @getTime() + 0.25


    @setTime preAnimationTime
    return model.page or model.highlight

  ###*
  Runs a command from the layout panel
  @memberof NFPartComp
  @returns {NFPartComp} self
  @param {Object} model - the parameters
  ###
  runLayoutCommand: (model) ->

    cmd =
      FST: "fullscreen-title"
      ADD_PAGE_SMALL: "add-small"
      SHRINK: "shrink-page"
      EXPOSE: "expose"
      EXPAND: "expand"
      ANCHOR: "anchor"
      END_ELEMENT: "end-element"
      SWITCH_PAGE: "switch-to-page"
      BUBBLE: "bubble"

    if model.target instanceof Array
      if model.target.length is 1
        model.target = model.target[0]
      else
        multipleTargets = yes

    # Rewriting this block to check command first
    switch model.command
      when cmd.EXPAND
        # Can only expand a single highlight layer
        throw new Error "Can't expand with multiple layers selected" if multipleTargets
        throw new Error "Can only expand a highlight layer" if model.target.class isnt "NFHighlightLayer"

        pageComp = new NFPageComp aeq.getComp(model.target.containingComp.name)
        matchedLayers = pageComp.layersWithName model.target.name
        throw new Error "Can't find layer!" if matchedLayers.isEmpty()
        target = null
        matchedLayers.forEach (layer) =>
          target = layer if layer.index() is model.target.index
        throw new Error "No target shape or highlight found!" unless target?

        currTime = @getTime()

        # Let's get the target page layer first
        layersForPage = @layersForPage pageComp
        startTime = null
        targetPageLayer = null
        unless layersForPage.isEmpty()
          layersForPage.forEach (layer) =>
            startTime = layer.$.startTime
            targetPageLayer = layer if layer.isActive()
        throw new Error "No target page layer found - Confirm that there's an
                         active page at this time that contains the highlight or
                         shape layer you're trying to show. This error can
                         sometimes happen when there are two highlights with the
                         same name in a PDF and you're trying to show the wrong
                         one." unless targetPageLayer?

        bgSolid = null
        # First, make sure we actually wanna do this. Is there an active ref that this expands the highlight of?
        refLayers = @searchLayers("[ref]")
        unless refLayers.isEmpty()
          activeRefs = new NFLayerCollection()
          refLayers.forEach (ref) =>
            if ref.isActive()
              if ref.getName().includes "FlightPath"
                bgSolid = ref
              else unless (ref.$ instanceof ShapeLayer)
                activeRefs.add ref
          if activeRefs.count() isnt 1
            throw new Error "Can only animate an expand if there's just one
                             matching active ref. This is likely because the
                             playhead is not over the ref layer, or there are
                             multiple layers active at this time that have the
                             same (or very similar names) to the ref layer."
          else
            refLayer = activeRefs.get(0)

        refLayer.expandTo
          layer: target
          duration: model.settings.durations.expandTransition

        group = targetPageLayer.getPaperLayerGroup()
        return alert "No group and null found for the target page layer (#{targetPageLayer.getName()}). Try deleting it and adding again before running." unless group?
        group.assignControlLayer(target, null, no)

        layerAbove = targetPageLayer.getPaperLayerGroup().getControlLayers().getBottommostLayer() ? targetPageLayer.getPaperLayerGroup().paperParent
        refLayer.moveAfter layerAbove

        controlLayer = target.getControlLayer()
        controlLayer.removeSpotlights()

        expandLayerControl = bgSolid.addEffect("ADBE Layer Control")
        expandLayerControl.name = "Expand Tracker"
        expandLayerControl.property("Layer").setValue controlLayer.index()

        @setTime currTime + model.settings.durations.expandTransition

      when cmd.EXPOSE
        # Can only expand a single highlight layer
        throw new Error "Can't expose with multiple targets" if multipleTargets

        pageComp = new NFPageComp aeq.getComp(model.target.containingComp.name)
        matchedLayers = pageComp.layersWithName model.target.name
        throw new Error "Can't find layer!" if matchedLayers.isEmpty()
        target = null
        matchedLayers.forEach (layer) =>
          target = layer if layer.index() is model.target.index
        throw new Error "No target shape or highlight found!" unless target?

        currTime = @getTime()

        # Let's get the target page layer first
        layersForPage = @layersForPage pageComp
        startTime = null
        targetPageLayer = null
        unless layersForPage.isEmpty()
          layersForPage.forEach (layer) =>
            startTime = layer.$.startTime
            targetPageLayer = layer if layer.isActive()
        throw new Error "No target page layer found - Confirm that there's an
                         active page at this time that contains the highlight or
                         shape layer you're trying to show. This error can
                         sometimes happen when there are two highlights with the
                         same name in a PDF and you're trying to show the wrong
                         one." unless targetPageLayer?

        # Duplicate and convert to reference layer
        refLayer = targetPageLayer.createReferenceLayer
          target: target
          maskExpansion: model.settings.maskExpansion
          fillPercentage: model.settings.expose.fillPercentage
          maxScale: model.settings.expose.maxScale

        # Add the HCL
        group = targetPageLayer.getPaperLayerGroup()
        return alert "No group and null found for the target page layer (#{targetPageLayer.getName()}). Try deleting it and adding again before running." unless group?
        group.assignControlLayer(target, null, no) if model.target.class is "NFHighlightLayer"

        layerAbove = targetPageLayer.getPaperLayerGroup().getControlLayers().getBottommostLayer() ? targetPageLayer.getPaperLayerGroup().paperParent
        refLayer.moveAfter layerAbove
        refLayer.startAt @getTime()

        # Animate In
        refLayer.centerAnchorPoint()
        refLayer.animateIn model.settings.durations.refTransition

        flightPath = refLayer.flightPath()
        # flightPath.$.locked = no
        group.gatherLayers(new NFLayerCollection([targetPageLayer, refLayer, refLayer.flightPath()]), false)
        # flightPath.$.locked = yes

        if model.target.class is "NFHighlightLayer"
          controlLayer = target.getControlLayer()
          controlLayer.removeSpotlights()

        if model.target.class is "NFShapeLayer"
          target.transform("Opacity").setValue 0

        @setTime currTime + model.settings.durations.refTransition

      when cmd.BUBBLE
        # Can only expand a single highlight layer
        throw new Error "Can't bubble with multiple targets" if multipleTargets

        pageComp = new NFPageComp aeq.getComp(model.target.containingComp.name)
        matchedLayers = pageComp.layersWithName model.target.name
        throw new Error "Can't find layer!" if matchedLayers.isEmpty()
        target = null
        matchedLayers.forEach (layer) =>
          target = layer if layer.index() is model.target.index
        throw new Error "No target shape or highlight found!" unless target?

        currTime = @getTime()

        # Let's get the target page layer first
        layersForPage = @layersForPage pageComp
        startTime = null
        targetPageLayer = null
        unless layersForPage.isEmpty()
          layersForPage.forEach (layer) =>
            startTime = layer.$.startTime
            targetPageLayer = layer if layer.isActive()
        throw new Error "No target page layer found - Confirm that there's an
                         active page at this time that contains the highlight or
                         shape layer you're trying to show. This error can
                         sometimes happen when there are two highlights with the
                         same name in a PDF and you're trying to show the wrong
                         one." unless targetPageLayer?

        group = targetPageLayer.getPaperLayerGroup()
        group.assignControlLayer target, currTime, no

        if model.target.class is "NFHighlightLayer"
          controlLayer = target.getControlLayer()
          controlLayer.removeSpotlights()

      when cmd.ANCHOR
        allTargets = if multipleTargets then model.target else [model.target]

        for theTarget in allTargets
          throw new Error "Can only reanchor a ref layer" if theTarget.class isnt "NFReferencePageLayer"
          refLayer = @layerWithName theTarget.name

          sourceLayer = refLayer.referencedSourceLayer()
          pageLayer = refLayer.referencedPageLayer()
          sourceRect = new Rect pageLayer.sourceRectForLayer(sourceLayer)

          refLayer.panBehindTo sourceRect.centerPoint()
          refLayer.$.label = 8


      when cmd.END_ELEMENT
        allTargets = if multipleTargets then model.target else [model.target]
        offset = 0
        mixedClass = no

        # Check if we should do a 'smart out' where the refs leave just before the page
        classTypes = []
        for theTarget in allTargets
          # throw new Error "Can only end element on ref and page layers for now" unless theTarget.class is "NFReferencePageLayer" or theTarget.class is "NFPageLayer"
          time = @getTime()
          classTypes.push(theTarget.class) if classTypes.indexOf(theTarget.class) < 0
        if classTypes.length > 1
          mixedClass = yes
          offset = model.settings.durations.multiEndOffset

        for theTarget in allTargets
          target = @layerWithName theTarget.name
          time = @getTime()
          layersToTrim = target.getChildren().add target

          if theTarget.class is "NFReferencePageLayer"
            # Find and add the control layer
            highlightName = target.referencedSourceLayer()
            pdfNumber = target.getPDFNumber()
            controlLayers = @searchLayers NFHighlightControlLayer.nameForPDFNumberAndHighlight pdfNumber, highlightName
            # FIXME: find the expands here
            unless controlLayers.count() is 0
              controlLayers.forEach (cLayer) =>
                layersToTrim.add cLayer

            layersToTrim.forEach (layer) =>
              layer.$.outPoint = Math.min((time - offset), layer.$.outPoint)

            flightPath = target.flightPath()
            flightPath.$.outPoint = (time - offset) if flightPath.$.outPoint > (time - offset)

            target.animateOut model.settings.durations.refTransition

          else if theTarget.class is "NFPageLayer"

            layersToTrim.forEach (layer) =>
              layer.$.outPoint = Math.min time, layer.$.outPoint

              # Let's also grab any flightpath layers
              flightPaths = new NFLayerCollection()
              @activeLayers().forEach (layer) =>
                if layer.getName().includes("FlightPath") and layer.$.outPoint >= time
                  layer.$.outPoint = time

              # Citation layer...
              target.getPaperLayerGroup().getCitationLayer().hide time

            target.slideOut
              length: model.settings.durations.slideOut

          else
            if theTarget.name.indexOf("NF-WEBSITE") >= 0
              layersToTrim.forEach (layer) =>
                layer.$.outPoint = Math.min((time - offset), layer.$.outPoint)
              target.slideOut
                toEdge: NFComp.BOTTOM
            else
              layersToTrim.forEach (layer) =>
                layer.$.outPoint = Math.min((time - offset), layer.$.outPoint)


      when cmd.SHRINK
        throw new Error "can't shrink multiple targets at once" if multipleTargets
        throw new Error "can only shrink page layers" if model.target.class isnt "NFPageLayer"
        target = @layerWithName model.target.name
        time = @getTime()

        target.animateToConstraints
          time: time
          duration: model.settings.durations.pageShrink
          width: 34
          right: 4.5
          top: 11.5
        @setTime time + model.settings.durations.pageShrink

      when cmd.FST
        throw new Error "can't grow multiple targets at once" if multipleTargets

        if model.target.class is "NFPageComp"
          target = new NFPageComp aeq.getComp(model.target.name)
          time = @getTime()

          shouldAnimate = yes
          scaleVal = [model.settings.transforms.page.scale.large, model.settings.transforms.page.scale.large, model.settings.transforms.page.scale.large]
          posVal = model.settings.transforms.page.position.large

          newPageLayer = @insertPage
            page: target
            continuous: yes
            animate: shouldAnimate
            animationDuration: model.settings.durations.slideIn
          group = newPageLayer.getPaperLayerGroup()
          pageParent = newPageLayer.getParent()
          newPageLayer.setParent()
          newPageLayer.transform('Scale').setValue scaleVal
          newPageLayer.transform('Position').setValue posVal
          newPageLayer.setParent(pageParent)
          newPageLayer.effect('Drop Shadow')?.enabled = no

          # Check if we've just obscured a visible ref layer
          activeRefs = @activeRefs()
          if activeRefs.count() > 0
            # layersToRise = new NFLayerCollection
            activeRefs.forEach (ref) =>
              # layersToRise.add ref
              # layersToRise.add ref.flightPath()
              if ref.getPDFNumber() isnt group.getPDFNumber()
                ref.moveBefore pageParent
                ref.flightPath().moveAfter ref

          group.getCitationLayer().show time, @$.duration - time
          @setTime time + model.settings.durations.slideIn

          group.gatherLayer newPageLayer

        else if model.target.class is "NFPageLayer"
          target = @layerWithName model.target.name
          time = @getTime()

          target.animateToConstraints
            time: time
            duration: model.settings.durations.pageGrow
            width: model.settings.constraints.fst.width
            top: model.settings.constraints.fst.top
            centerX: yes
          @setTime time + model.settings.durations.pageGrow
        else throw new Error "can only run FST on page comp or page layer"

      when cmd.ADD_PAGE_SMALL
        throw new Error "target isn't a pagecomp" unless model.target.class is "NFPageComp"
        target = new NFPageComp aeq.getComp(model.target.name)
        time = @getTime()

        shouldAnimate = yes
        scaleVal = [model.settings.transforms.page.scale.small, model.settings.transforms.page.scale.small, model.settings.transforms.page.scale.small]
        posVal = model.settings.transforms.page.position.small

        newPageLayer = @insertPage
          page: target
          continuous: yes
          animate: shouldAnimate
          animationDuration: model.settings.durations.slideIn
        group = newPageLayer.getPaperLayerGroup()
        pageParent = newPageLayer.getParent()
        newPageLayer.setParent()
        newPageLayer.transform('Scale').setValue scaleVal
        newPageLayer.transform('Position').setValue posVal
        newPageLayer.setParent(pageParent)
        newPageLayer.effect('Drop Shadow')?.enabled = no

        # Check if we've just obscured a visible ref layer
        activeRefs = @activeRefs()
        if activeRefs.count() > 0
          # layersToRise = new NFLayerCollection
          activeRefs.forEach (ref) =>
            # layersToRise.add ref
            # layersToRise.add ref.flightPath()
            if ref.getPDFNumber() isnt group.getPDFNumber()
              ref.moveBefore pageParent
              ref.flightPath().moveAfter ref

        group.getCitationLayer().show time, @$.duration - time
        @setTime time + model.settings.durations.slideIn
        group.gatherLayer newPageLayer

      when cmd.SWITCH_PAGE
        throw new Error "target isn't a pagecomp" unless model.target.class is "NFPageComp"
        target = new NFPageComp aeq.getComp(model.target.name)
        time = @getTime()

        shouldAnimate = no
        activePage = @activePage()
        unless activePage?
          throw new Error "can't run SWITCH_PAGE without an already active page at this time"

        pageParent = activePage.getParent()
        activePage.setParent()
        scaleVal = activePage.transform('Scale').value
        posVal = activePage.transform('Position').value
        activePage.setParent pageParent

        # fade out the ActivePage
        activePage.$.outPoint = time + model.settings.durations.fadeIn * 2
        activePage.fadeOut model.settings.durations.fadeIn

        # Let's also fade any flightpath layers
        flightPaths = new NFLayerCollection()
        @activeLayers().forEach (layer) =>
          if layer.getName().includes("FlightPath") and layer.$.outPoint >= time + model.settings.durations.fadeIn
            layer.$.outPoint = time + model.settings.durations.fadeIn

        newPageLayer = @insertPage
          page: target
          continuous: yes
          animate: shouldAnimate
          animationDuration: model.settings.durations.slideIn
        group = newPageLayer.getPaperLayerGroup()
        pageParent = newPageLayer.getParent()
        newPageLayer.setParent()
        newPageLayer.transform('Scale').setValue scaleVal
        newPageLayer.transform('Position').setValue posVal
        newPageLayer.setParent(pageParent)
        newPageLayer.effect('Drop Shadow')?.enabled = no

        newPageLayer.moveBefore activePage
        newPageLayer.fadeIn model.settings.durations.fadeIn
        @setTime time + model.settings.durations.fadeIn


  ###*
  Inserts a page at the current time
  @memberof NFPartComp
  @returns {NFPageLayer} the new page layer
  @param {Object} model - the parameters
  @param {NFPageComp} model.page - the page to insert
  @param {boolean} [model.init=yes] - if the page should be initialized
  @param {NFLayer} [model.above] - the layer to insert the page above. Can use
  only one of .above, .below or .at
  @param {NFLayer} [model.below] - the layer to insert the page below. Can use
  only one of .above, .below or .at
  @param {int} [model.at=0] - the index to insert the page at. Can use only
  one of .above, .below or .at
  @param {boolean} [model.animate=no] whether to animate the page in
  @param {float} [model.animationDuration=1] animation duration if animate is yes
  @param {float} [model.time=Current Time] The time to insert at
  @param {Enum} [model.pageTurn=PAGETURN_NONE] the pageTurn of the page
  @param {boolean} [model.continuous=no] whether to start the page at the
  first frame of it's composition that we haven't seen yet.
  @throws Throw error if given values for more than one of .above, .below,
  and .at
  ###
  insertPage: (model) ->
    @log "Inserting page: #{model.page.$.name}"
    throw new Error "No page given to insert..." unless model.page? and model.page instanceof NFPageComp

    model.at = 1 unless model.above? or model.below? or model.at?
    model.time = model.time ? @getTime()
    model.pageTurn = model.pageTurn ? NFPageLayer.PAGETURN_NONE
    model.continuous = model.continuous ? no
    model.animationDuration = model.animationDuration ? 2
    pageLayer = @insertComp
      comp: model.page
      above: model.above
      below: model.below
      at: model.at
      time: model.time
    pageLayer.$.label = 4

    # Add the ghost page trackers if necessary
    ghostPageLayerName = "Ghost Pages"
    ghostPageDataLayerName = "ghost-page-data"
    unless @layerWithName(ghostPageLayerName)?
      ghostPageLayer = @addSolid
        color: [1,1,1]
        name: ghostPageLayerName
      ghostPageLayer.moveBefore @greenscreenLayer()
      ghostPageLayer.addSlider("Page Offset", 100)
      ghostPageLayer.addSlider("Page Opacity", 60)

      for i in [1..4]
        # Setup the mask
        newMask = ghostPageLayer.mask().addProperty "Mask"
        newMask.maskShape.expression = NFTools.readExpression "ghost-pages-mask-path-expression"
        newMask.maskOpacity.expression = NFTools.readExpression "ghost-pages-mask-opacity-expression"
    unless @layerWithName(ghostPageDataLayerName)?
      dataLayer = @addTextLayer
        at: @allLayers().count()-1
        time: 0
      dataLayer.property("Text").property("Source Text").expression = NFTools.readExpression "ghost-pages-data-expression"
      dataLayer.$.enabled = no
      dataLayer.$.name = ghostPageDataLayerName

    unless model.init is no
      pageLayer.initTransforms().init()
      group = new NFPaperLayerGroup pageLayer.assignPaperParentLayer()
      group.assignCitationLayer()
      group.extend()


    if model.frameUp? and model.frameUp.highlight?
      pageLayer.frameUpHighlight model.frameUp

    if model.continuous
      pageLayer.makeContinuous()

    if model.animate is yes
      pageLayer.slideIn
        length: model.animationDuration

    if model.pageTurn is NFPageLayer.PAGETURN_FLIPPED_UP or model.pageTurn is NFPageLayer.PAGETURN_FLIPPED_DOWN
      pageLayer.setupPageTurnEffect model.pageTurn
    else if model.pageTurn isnt NFPageLayer.PAGETURN_NONE
      throw new Error "Invalid pageturn type to insert page with"


    layersForPage = @layersForPage model.page
    layersForPage.differentiate()

    return pageLayer

  ###*
  Adds a new placeholder layer to the comp, above the currently active group. If a
  placeholder is already active, replace the placeholder text with the new one at
  the given time.
  @memberof NFPartComp
  @param {Object} model
  @param {String} [model.text] - the placeholder text to show over the layer
  @param {float} [model.time=currTime] - the start time of the placeholder layer
  @param {float} [model.duration] - the length of the placeholder layer. If not
  given a duration, the layer will continue indefinitely.
  @returns {NFPartComp} self
  ###
  addPlaceholder: (model) ->
    model.time = model.time ? @getTime()
    model.duration = model.duration ? @$.duration - model.time

    activePDF = @activePDF model.time
    if activePDF?
      activeGroup = @groupFromPDF activePDF
      activeGroup.trimActivePlaceholder model.time

      placeholder = @addTextLayer
        text: model.text
        time: model.time
        duration: model.duration
        fillColor: [0,0.6,0.9]
        strokeWidth: 10
        strokeColor: [0,0,0]
        applyStroke: yes
        below: activeGroup.getCitationLayer()
        justification: ParagraphJustification.CENTER_JUSTIFY
        fontSize: 60
      placeholder.transform().property("Position").setValue [960, 980]
      placeholder.$.name = "INSTRUCTION: #{model.text}"

    else
      # FIXME: Should be able to catch these non-attached ones and trim...
      placeholder = @addTextLayer
        text: model.text
        time: model.time
        duration: model.duration
        fillColor: [0,0.6,0.9]
        strokeWidth: 10
        strokeColor: [0,0,0]
        applyStroke: yes
        justification: ParagraphJustification.CENTER_JUSTIFY
        fontSize: 60
      placeholder.transform().property("Position").setValue [960, 980]
      placeholder.$.name = "INSTRUCTION: #{model.text}"

    @

  ###*
  Adds a new gaussy layer to the comp, above the currently active group. If a
  gaussy is already active, replace the placeholder text with the new one at
  the given time.
  @memberof NFPartComp
  @param {Object} model
  @param {String} [model.placeholder] - the placeholder text to show over the layer
  @param {float} [model.time=currTime] - the start time of the gaussy layer
  @param {float} [model.duration] - the length of the gaussy layer. If not given
  a duration, the layer will continue indefinitely.
  @param {layer} [model.layer] - the layer to insert the gaussy above
  @returns {NFGaussyLayer} the layer added
  ###
  addGaussy: (model) ->
    model ?= {}
    model.time = model.time ? @getTime()
    model.duration = model.duration ? @$.duration - model.time

    activePDF = @activePDF model.time
    if activePDF? or model.layer?
      activeGroup = @groupFromPDF(activePDF) unless model.layer?

      activeGaussy = @activeGaussy model.time
      if activeGaussy?
        # If there's already an active one, switch the placeholder if possible.
        children = activeGaussy.getChildren()
        belowTarget = null
        unless children.isEmpty()
          children.forEach (testChild) =>
            if testChild.$ instanceof TextLayer
              testChild.$.outPoint = model.time
              belowTarget = testChild
        belowTarget = belowTarget ? activeGaussy
      else
        @log "Adding a gaussy layer at time: #{model.time}"
        gaussy = NFGaussyLayer.newGaussyLayer
          layer: activeGroup?.getCitationLayer() ? model.layer
          time: model.time
          duration: model.duration

        activeGroup.trimActiveSpotlights(model.time + 0.5) unless model.layer?

      if model.placeholder?
        placeholder = @addTextLayer
          text: model.placeholder
          time: model.time
          duration: model.duration
          fillColor: [1,0,0]
          above: belowTarget ? gaussy
          justification: ParagraphJustification.CENTER_JUSTIFY
          fontSize: 100
        placeholder.setParent activeGaussy ? gaussy
        placeholder.$.name = "FIXME: #{model.placeholder}"

    else
      throw new Error "No active group to create a gaussy layer on top of"

    return gaussy

  ###*
  Hides the active gaussy layer, if one exists.
  @memberof NFPartComp
  @param {float} [time=currTime] - the end time of the gaussy layer
  @returns {NFPartComp} self
  ###
  hideGaussy: (time) ->
    time = time ? @getTime()
    activeGaussies = @activeLayers(time).searchLayers "Gaussy"
    activeGaussies.forEach (testLayer) =>
      if testLayer.$.isSolid()
        @log "Hiding gaussy layer at time: #{time}"
        testLayer.$.outPoint = time
        children = testLayer.getChildren()
        unless children.isEmpty()
          children.forEach (child) =>
            child.$.outPoint = time unless child.$.outPoint < time

    @

  ###*
  Returns whether or not there's an active gaussy layer at the given time
  @memberof NFPartComp
  @param {float} [time=currTime] - the time to check
  @returns {Boolean} if there is a gaussy active at the current time
  ###
  gaussyActive: (time) ->
    return @activeGaussy(time)?

  ###*
  Trims all the animation layers in this comp to the given time
  @memberof NFPartComp
  @param {float} [time=currTime] - the time to check
  @returns {Boolean} if there is a gaussy active at the current time
  ###
  trimTo: (time) ->
    @activeLayers(time).forEach (layer) =>
      layer.$.outPoint = time

  ###*
  Returns an active gaussy if one exists, or null. DIFFERENT FROM #gaussyActive
  @memberof NFPartComp
  @param {float} [time=currTime] - the time to check
  @returns {NFGaussyLayer | null} the active gaussy at the given time, or null
  ###
  activeGaussy: (time) ->
    time = time ? @getTime()

    searchResults = @activeLayers(time).searchLayers "Gaussy"
    if searchResults.isEmpty()
      return null
    else
      gaussyFound = null
      searchResults.forEach (testLayer) =>
        gaussyFound = testLayer if testLayer.$.isSolid()
      return gaussyFound


  ###*
  Converts one or more selected Layers to a browser window precomp
  @memberof NFPartComp
  @param {NFLayer | NFLayerCollection} layers - the layer or layers to convert
  @returns {NFLayer} the web comp layer
  ###
  addBrowserWindow: (layers) ->

    layers = new NFLayerCollection([layers]) if layers instanceof NFLayer
    alert "Error adding browser window: invalid layer collection or layer" unless layers instanceof NFLayerCollection and layers.count() > 0

    @$.openInViewer()
    app.executeCommand 2004 # Deselect all

    layers.sortByIndex()
    layers.forEach (theLayer, i, allLayers) =>
      theLayer.$.selected = yes

    app.executeCommand 19 # Copy

    browserImage = NFProject.findItem "safari-browser-v01.ai"

    webCompsFolder = NFProject.findItem "Website Comps"
    unless webCompsFolder
      assetsFolder = NFProject.findItem "Assets"
      webCompsFolder = assetsFolder.items.addFolder "Website Comps"

    matteCompItem = NFProject.findItemIn "Browser Matte", webCompsFolder
    if matteCompItem?
      matteComp = new NFComp matteCompItem
    else
      matteComp = new NFComp webCompsFolder.items.addComp("Browser Matte", 1920, 1080, 1, 600, 30)
      matteSolid = new NFLayer matteComp.$.layers.addSolid([0.5,0.5,0.5], 'Matte Layer', 1920, 1080, 1)
      newMask = matteSolid.mask().addProperty "Mask"
      newMask.name = "Mask 1"
      newMask.maskShape.expression = "createPath(points = [[0,132], [1920, 132], [1920, 1080], [0, 1080]], inTangents = [], outTangents = [], is_closed = true);"

    suffix = if layers.count() is 1 then layers.get(0).getName() else "Multiple Layers"
    webComp = new NFComp webCompsFolder.items.addComp("NF-WEBSITE - #{suffix}", 1920, 1080, 1, 600, 30)

    webComp.$.openInViewer()
    app.executeCommand 20 # Paste

    pastedLayers = webComp.allLayers()
    preCompIndexes = []
    pastedLayers.forEach (theLayer, i, allLayers) =>
      theLayer.$.startTime = 0
      if theLayer.$.canSetCollapseTransformation
        theLayer.$.collapseTransformation = true
      else
        preCompIndexes.push theLayer.index()

    for idx in preCompIndexes
      newPreComp = webComp.$.layers.precompose [idx], "Browser Precomp - " + webComp.$.layer(idx).name, false
      newPreComp.parentFolder = webCompsFolder
      webComp.$.layer(idx).collapseTransformation = true

    webCompVisibleLayers = webComp.allLayers()

    browserLayer = new NFLayer webComp.$.layers.add(browserImage)
    browserLayer.transform("Scale").setValue [417.4, 417.4]
    browserLayer.transform("Anchor Point").setValue [0, 0]
    browserLayer.transform("Position").setValue [0, 0]
    browserLayer.$.collapseTransformation = true
    browserLayer.moveAfter webCompVisibleLayers.getBottommostLayer()

    matteLayer = webComp.insertComp
      comp: matteComp
      at: 0
      time: 0
    matteLayer.$.enabled = no

    webCompVisibleLayers.forEach (theLayer, i, allLayers) =>
      matteEffect = theLayer.addEffect("ADBE Set Matte3")
      matteEffect.property("Take Matte From Layer").setValue 1

    textLayer = webComp.addTextLayer
      text: "https://www.website.com/page/subpage/subpage/"
      above: matteLayer
      fontSize: 29
      font: "Proxima Nova"
    textLayer.transform("Position").setValue [353, 94]

    @$.openInViewer()
    webCompLayer = @insertComp
      comp: webComp
      above: layers.getTopmostLayer()
      time: layers.getEarliestLayer().$.inPoint
    webCompLayer.transform("Scale").setValue [94,94]
    webCompLayer.transform("Position").setValue [960,668]

    webCompLayer.slideIn
      fromEdge: NFComp.BOTTOM
    webCompLayer.$.motionBlur = yes

    webCompLayer.effect("Start Offset").property("Slider").setValue(1660)
    shadowProp = webCompLayer.addEffect('ADBE Drop Shadow')
    shadowProp.property('Opacity').setValue(51)
    shadowProp.property('Direction').setValue(0)
    shadowProp.property('Distance').setValue(10)
    shadowProp.property('Softness').setValue(60)

    layers.forEach (theLayer, i, allLayers) =>
      theLayer.remove()

    webCompLayer.$.label = 16
    return webCompLayer

  ###*
  Returns an active placeholder if one exists, or null.
  @memberof NFPartComp
  @param {float} [time=currTime] - the time to check
  @returns {NFLayer} the active placeholder layer at the given time, or null
  ###
  activePlaceholder: (time) ->
    time = time ? @getTime()

    foundPlaceholder = null
    @activeLayers(time).forEach (activeLayer) =>
      if activeLayer.getName().indexOf("INSTRUCTION:") >= 0
        foundPlaceholder = activeLayer
    return foundPlaceholder

  ###*
  Gets the active PDF at an optional time
  @memberof NFPartComp
  @param {float} [time] - the time to check at, or the current time by default
  @returns {NFPDF | null} The active PDF or null if none active
  ###
  activePDF: (time) ->
    activePage = @activePage(time)
    return activePage?.getPDF()

  ###*
  Gets the active NFPageLayer at a time (or current time by default). In this
  case, that means the topmost Page Layer that is not folded back, invisible,
  disabled, pre-start or post-end. Does not check ref layers
  @memberof NFPartComp
  @param {float} [time] - the time to check at, or the current time by default
  @returns {NFPageLayer | null} The active page layer or null if none
  ###
  activePage: (time) ->
    # Set the current time to the test time, but we'll need to set it back later.
    if time?
      originalTime = @getTime()
      @setTime(time)

    activePage = null
    activeLayers = @activeLayers time
    until activeLayers.isEmpty()
      topLayer = activeLayers.getTopmostLayer()
      if topLayer instanceof NFPageLayer and not (topLayer instanceof NFReferencePageLayer)
        if topLayer.pageTurnStatus(time) isnt NFPageLayer.PAGETURN_FLIPPED_UP and topLayer.property("Transform").property("Opacity").value isnt 0
          activePage = topLayer
          break

      activeLayers.remove(topLayer)

    @setTime originalTime if originalTime?
    return activePage

  ###*
  Gets any active refs at the current time
  @memberof NFPartComp
  @param {float} [time] - the time to check at, or the current time by default
  @returns {NFPageLayerCollection} The active refs
  ###
  activeRefs: (time) ->
    # Set the current time to the test time, but we'll need to set it back later.
    if time?
      originalTime = @getTime()
      @setTime(time)
    else time = @getTime()

    activeRefs = new NFPageLayerCollection()
    @allLayers().forEach (layer) =>
      if layer instanceof NFReferencePageLayer and layer.$.inPoint < time < layer.$.outPoint
        activeRefs.add layer

    @setTime originalTime if originalTime?
    return activeRefs


  ###*
  Returns an NFPaperLayerGroup for a given PDF in the part comp
  @memberof NFPartComp
  @param {NFPDF} pdf - the PDF to look for
  @returns {NFPaperLayerGroup | null} The found group
  ###
  groupFromPDF: (pdf) ->
    throw new Error "given pdf is not an NFPDF" unless pdf instanceof NFPDF
    matchedLayers = new NFLayerCollection
    parentLayer = @layerWithName pdf.getName()

    if parentLayer?
      return new NFPaperLayerGroup parentLayer
    else
      return null


  ###*
  Returns an NFPageLayerCollection of NFPageLayers in this comp that
  contain the given NFPageComp. Does not include reference layers by default.
  @memberof NFPartComp
  @param {NFPageComp} page - the page to look for
  @param {boolean} [includeReferenceLayers=no] - If this function should also return reference layers
  @returns {NFPageLayerCollection} The found page layers
  ###
  layersForPage: (page, includeReferenceLayers = no) ->
    throw new Error "given page is not an NFPageComp" unless page instanceof NFPageComp
    matchedPages = new NFPageLayerCollection
    @allLayers().forEach (theLayer) =>
      if theLayer instanceof NFPageLayer and theLayer.getPageComp().is page
        if includeReferenceLayers or not theLayer.isReferenceLayer()
          matchedPages.add theLayer
    return matchedPages

# Class Methods
NFPartComp = Object.assign NFPartComp,

  ###*
  # Returns whether the CompItem can be NFPartComp
  # @memberof NFComp
  # @param {CompItem}
  # @returns {boolean} if the given CompItem fits the criteria to be a NFPartComp
  ###
  canBePartComp: (compItem) ->
    return compItem.name.indexOf("Part") >= 0
