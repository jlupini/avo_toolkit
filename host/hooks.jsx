var addBrowser, addGaussy, applyFMFTransition, changeLineCountForHighlightAtIndex, clearFMFTransition, convertShapeToHighlight, createHighlightFromAnnotation, debug, deleteHighlightAtIndex, e, editDefaultsFile, emphasisLayerSelected, error, focusOn, getActivePageFile, getEmphasisProperties, getFullPDFTree, getPollingData, linkHighlightToSelectedLayer, makeEmphasisLayer, openComp, openDocument, processRawAnnotationData, runLayoutCommand, runTool, setBlendingMode, setEmphasisProperties, splitHighlightAtIndex, toggleGuideLayers, transitionClearIn, transitionClearOut, transitionFadeIn, transitionFadeOut, transitionFadeScaleIn, transitionFadeScaleOut, transitionSlideIn, transitionSlideOut, unlinkHighlightAtIndex;

try {
  openDocument = function(location) {
    var docRef, fileRef;
    alert('Testing server');
    fileRef = new File(location);
    docRef = app.open(fileRef);
  };
  debug = function() {
    $.level = 2;
    debugger;
  };
  runTool = function(toolKey) {
    var category, choice, key;
    for (key in toolRegistry) {
      category = toolRegistry[key];
      if (category.tools[toolKey] != null) {
        choice = category.tools[toolKey];
      }
    }
    if (choice == null) {
      return alert("No Tool Selected! (key was " + toolKey + ")");
    }
    if (choice.callback != null) {
      app.beginUndoGroup("NF Tool: " + choice.name);
      choice.callback();
      return app.endUndoGroup();
    } else {
      return openScript(choice.callbackScript);
    }
  };
  editDefaultsFile = function(newContents) {
    var finalContents, oldContents;
    oldContents = "";
    finalContents = "";
    NFTools.editProjectFile("./.animation_settings.json", (function(_this) {
      return function(theFileText) {
        if (newContents != null) {
          if (newContents === "") {
            return finalContents = "";
          } else {
            return finalContents = JSON.stringify(newContents);
          }
        } else if (theFileText != null) {
          return finalContents = theFileText;
        } else {
          return finalContents = "";
        }
      };
    })(this));
    return finalContents;
  };
  makeEmphasisLayer = function() {
    var selectedLayer;
    selectedLayer = NFProject.singleSelectedLayer();
    if (selectedLayer == null) {
      return alert("Please select a single layer first");
    }
    return selectedLayer.addEmphasisLayer();
  };
  emphasisLayerSelected = function() {
    var selectedLayer;
    selectedLayer = NFProject.singleSelectedLayer();
    return (selectedLayer != null) && selectedLayer instanceof NFEmphasisLayer;
  };
  setEmphasisProperties = function(paramsJSON) {
    var params, selectedLayer;
    selectedLayer = NFProject.singleSelectedLayer();
    if (selectedLayer == null) {
      return alert("Please select a single emphasis layer");
    }
    params = JSON.parse(paramsJSON);
    if (params.name == null) {
      return alert("Error - no cylon specified");
    }
    if (params.color != null) {
      selectedLayer.effect(params.name).property("Color").setValue(params.color);
    }
    if (params.thickness != null) {
      selectedLayer.effect(params.name).property("Thickness").setValue(params.thickness);
    }
    if (params.lag != null) {
      return selectedLayer.effect(params.name).property("Lag").setValue(params.lag);
    }
  };
  getEmphasisProperties = function() {
    var allEffects, layer, selectedLayer;
    selectedLayer = NFProject.singleSelectedLayer();
    if (selectedLayer == null) {
      return alert("Please select a single layer first");
    }
    allEffects = {};
    layer = new aeq.Layer(selectedLayer.$);
    layer.forEachEffect(function(e) {
      return allEffects[e.name] = {
        thickness: e.property("Thickness").value,
        lag: e.property("Lag").value,
        color: e.property("Color").value
      };
    });
    return allEffects;
  };
  transitionFadeIn = function() {
    var theLayer;
    theLayer = NFProject.singleSelectedLayer();
    if (theLayer == null) {
      return alert("Please select a single layer first");
    }
    return theLayer.fadeIn();
  };
  transitionFadeOut = function() {
    var theLayer;
    theLayer = NFProject.singleSelectedLayer();
    if (theLayer == null) {
      return alert("Please select a single layer first");
    }
    return theLayer.fadeOut();
  };
  transitionSlideIn = function() {
    var theLayer;
    theLayer = NFProject.singleSelectedLayer();
    if (theLayer == null) {
      return alert("Please select a single layer first");
    }
    return theLayer.slideIn();
  };
  transitionSlideOut = function() {
    var theLayer;
    theLayer = NFProject.singleSelectedLayer();
    if (theLayer == null) {
      return alert("Please select a single layer first");
    }
    return theLayer.slideOut();
  };
  transitionClearIn = function() {
    var theLayer;
    theLayer = NFProject.singleSelectedLayer();
    alert("deleting in and out NF transitions");
    if (theLayer == null) {
      return alert("Please select a single layer first");
    }
    return theLayer.removeNFMarkers();
  };
  transitionClearOut = function() {
    var theLayer;
    theLayer = NFProject.singleSelectedLayer();
    alert("deleting in and out NF transitions");
    if (theLayer == null) {
      return alert("Please select a single layer first");
    }
    return theLayer.removeNFMarkers();
  };
  transitionFadeScaleIn = function() {
    return alert("haven't done this yet");
  };
  transitionFadeScaleOut = function() {
    return alert("haven't done this yet");
  };
  focusOn = function(req) {
    var activeComp, activeLayers, looseLayers, tightLayers;
    app.beginUndoGroup("Change Focus (via NF Panel)");
    if (req === "all") {
      NFProject.activeComp().allLayers().forEach((function(_this) {
        return function(layer) {
          if (!(layer.getName().indexOf("FlightPath") >= 0)) {
            return layer.setShy(false);
          }
        };
      })(this));
      NFProject.activeComp().$.hideShyLayers = true;
    } else if (req === "pdf") {
      activeComp = NFProject.activeComp();
      activeLayers = activeComp.activeLayers();
      if (activeLayers.isEmpty()) {
        return alert("No layers active!");
      }
      looseLayers = new NFLayerCollection;
      activeLayers.forEach((function(_this) {
        return function(layer) {
          var group;
          if (!(layer instanceof NFCitationLayer || layer.getName().indexOf("Backing for") >= 0)) {
            looseLayers.add(layer);
          }
          if (!layer.is(activeComp.greenscreenLayer())) {
            looseLayers.add(layer.getChildren(true));
          }
          if (layer instanceof NFPageLayer) {
            group = layer.getPaperLayerGroup();
            if (group != null) {
              looseLayers.add(group.getMembers());
              return looseLayers.add(group.paperParent);
            }
          }
        };
      })(this));
      activeComp.allLayers().forEach((function(_this) {
        return function(layer) {
          return layer.setShy(!looseLayers.containsLayer(layer));
        };
      })(this));
      activeComp.$.hideShyLayers = true;
    } else if (req === "active") {
      activeComp = NFProject.activeComp();
      activeLayers = activeComp.activeLayers();
      if (activeLayers.isEmpty()) {
        return alert("No layers active!");
      }
      tightLayers = new NFLayerCollection;
      activeLayers.forEach((function(_this) {
        return function(layer) {
          var group, time;
          if (!(layer instanceof NFCitationLayer || layer.getName().indexOf("Backing for") >= 0)) {
            tightLayers.add(layer);
          }
          if (layer instanceof NFPageLayer) {
            group = layer.getPaperLayerGroup();
            if (group != null) {
              tightLayers.add(group.paperParent);
              tightLayers.add(group.getCitationLayer());
              time = activeComp.getTime();
              return group.getControlLayers().forEach(function(control) {
                if (control.$.inPoint <= time && control.$.outPoint >= time) {
                  return tightLayers.add(control);
                }
              });
            }
          }
        };
      })(this));
      activeComp.allLayers().forEach((function(_this) {
        return function(layer) {
          return layer.setShy(!tightLayers.containsLayer(layer));
        };
      })(this));
      activeComp.$.hideShyLayers = true;
    } else {
      alert("Error: Invalid focus request");
    }
    return app.endUndoGroup();
  };
  setBlendingMode = function(mode) {
    var modeCode;
    app.beginUndoGroup("Set Blend Mode (via NF Panel)");
    if (mode === "overlay") {
      modeCode = BlendingMode.OVERLAY;
    } else if (mode === "multiply") {
      modeCode = BlendingMode.MULTIPLY;
    } else if (mode === "screen") {
      modeCode = BlendingMode.SCREEN;
    } else {
      modeCode = BlendingMode.NORMAL;
    }
    NFProject.selectedLayers().forEach((function(_this) {
      return function(layer) {
        return layer.$.blendingMode = modeCode;
      };
    })(this));
    return app.endUndoGroup();
  };
  runLayoutCommand = function(model) {
    var activeComp, e, error;
    try {
      app.beginUndoGroup("Run Layout Command");
      activeComp = NFProject.activeComp();
      activeComp.runLayoutCommand(model);
      return app.endUndoGroup();
    } catch (error) {
      e = error;
      return alert("Error calling hook `runLayoutCommand`: " + e.message);
    }
  };
  openComp = function(model) {
    return aeq.getComp(model.name).openInViewer();
  };
  getFullPDFTree = function() {
    var allPageComps, contentTree, e, error, j, k, key, len, len1, outputTree, pageComp, pageCompArr, pageLayers, pdfNumber, shapeLayers, thisPDF, thisPage;
    try {
      contentTree = {};
      outputTree = {
        pdfs: []
      };
      allPageComps = NFProject.allPageComps();
      for (j = 0, len = allPageComps.length; j < len; j++) {
        pageComp = allPageComps[j];
        pdfNumber = pageComp.getPDFNumber();
        if (contentTree[pdfNumber] == null) {
          contentTree[pdfNumber] = [];
        }
        contentTree[pdfNumber].push(pageComp);
      }
      for (key in contentTree) {
        thisPDF = NFPDF.fromPDFNumber(key).simplify();
        thisPDF.pages = [];
        pageCompArr = contentTree[key];
        for (k = 0, len1 = pageCompArr.length; k < len1; k++) {
          pageComp = pageCompArr[k];
          thisPage = pageComp.simplify();
          thisPage.shapes = [];
          pageLayers = pageComp.allLayers();
          shapeLayers = new NFLayerCollection;
          pageLayers.forEach((function(_this) {
            return function(layer) {
              if (layer.$ instanceof ShapeLayer) {
                return shapeLayers.add(layer);
              }
            };
          })(this));
          if (!shapeLayers.isEmpty()) {
            shapeLayers.forEach((function(_this) {
              return function(shapeLayer) {
                return thisPage.shapes.push(shapeLayer.simplify());
              };
            })(this));
          }
          thisPDF.pages.push(thisPage);
        }
        outputTree.pdfs.push(thisPDF);
      }
      return JSON.stringify(outputTree);
    } catch (error) {
      e = error;
      return e;
    }
  };
  getPollingData = function() {
    var activeComp, activePage, aeqLayer, allLayers, compType, e, error, highlightLayers, i, j, k, l, layerType, model, prevLayer, ref, ref1, ref2, ref3, ref4, selectedAVLayers, selectedLayer, simpLayer, singleSelectedLayerSimplified, thisLayer;
    model = {};
    activeComp = app.project.activeItem;
    if (activeComp == null) {
      return "undefined";
    }
    try {
      if ((activeComp != null) && activeComp instanceof CompItem) {
        compType = activeComp.simpleReflection()["class"];
        if (compType === "NFPartComp") {
          activePage = null;
          allLayers = activeComp.layers;
          if (allLayers.length !== 0) {
            prevLayer = null;
            for (i = j = 1, ref = allLayers.length; 1 <= ref ? j <= ref : j >= ref; i = 1 <= ref ? ++j : --j) {
              thisLayer = allLayers[i];
              if (((ref1 = thisLayer.source) != null ? ref1.name.includes("NFPage") : void 0) && !thisLayer.name.includes('[ref]') && thisLayer.opacity.value !== 0 && (thisLayer.inPoint <= (ref2 = activeComp.time) && ref2 <= thisLayer.outPoint)) {
                if (prevLayer != null) {
                  if (thisLayer.index < prevLayer.index) {
                    activePage = thisLayer;
                  }
                } else {
                  activePage = thisLayer;
                }
                prevLayer = thisLayer;
              }
            }
          }
          if (activePage != null) {
            model.activePDF = activePage.source.getPDFNumber();
            model.activePage = activePage.simpleReflection();
          }
        } else if (compType === "NFPageComp") {
          allLayers = activeComp.layers;
          highlightLayers = [];
          if (allLayers.length !== 0) {
            prevLayer = null;
            for (i = k = 1, ref3 = allLayers.length; 1 <= ref3 ? k <= ref3 : k >= ref3; i = 1 <= ref3 ? ++k : --k) {
              thisLayer = allLayers[i];
              if (thisLayer instanceof ShapeLayer) {
                if (thisLayer.property("Effects").property("AV Highlighter") != null) {
                  if (thisLayer.property("Effects").property("Rect Hash") != null) {
                    highlightLayers.push({
                      name: thisLayer.name,
                      index: thisLayer.index,
                      rectHash: thisLayer.property("Effects").property("Rect Hash").property("Point").value
                    });
                  }
                }
              }
            }
          }
          model.highlightLayers = highlightLayers;
        }
        selectedAVLayers = activeComp.selectedLayers;
        if (selectedAVLayers.length === 0) {
          layerType = "no-layer";
        } else if (selectedAVLayers.length === 1) {
          selectedLayer = selectedAVLayers[0];
          singleSelectedLayerSimplified = selectedLayer.simpleReflection();
          layerType = singleSelectedLayerSimplified["class"];
          model.effects = [];
          aeqLayer = new aeq.Layer(selectedLayer);
          aeqLayer.forEachEffect((function(_this) {
            return function(e, i) {
              var effectIndex;
              if (e.matchName.includes("AV_")) {
                model.effects.push({
                  name: e.name,
                  matchName: e.matchName,
                  properties: {}
                });
                effectIndex = model.effects.length - 1;
                return e.forEach(function(prop) {
                  return model.effects[effectIndex].properties[prop.name] = {
                    value: prop.value
                  };
                });
              }
            };
          })(this));
        } else {
          layerType = "multiple-layers";
        }
        model.selectedLayers = [];
        if (singleSelectedLayerSimplified != null) {
          model.selectedLayers.push(singleSelectedLayerSimplified);
        } else if (selectedAVLayers.length > 0) {
          for (i = l = 0, ref4 = selectedAVLayers.length - 1; 0 <= ref4 ? l <= ref4 : l >= ref4; i = 0 <= ref4 ? ++l : --l) {
            simpLayer = selectedAVLayers[i].simpleReflection();
            model.selectedLayers.push(simpLayer);
          }
        }
        model.bodyClass = layerType + " " + compType;
      } else {
        model.bodyClass = "no-comp";
      }
      return JSON.stringify(model);
    } catch (error) {
      e = error;
      return alert("Error calling hook `getPollingData`: " + e.message);
    }
  };
  getActivePageFile = function() {
    var activeComp;
    activeComp = NFProject.activeComp();
    if (activeComp instanceof NFPageComp && (activeComp.getPDFLayer().$.source != null)) {
      return activeComp.getPDFLayer().$.source.file.fsName;
    } else {
      return null;
    }
  };
  processRawAnnotationData = function(rawData) {
    return NFPDFManager.processRawAnnotationData(rawData);
  };
  toggleGuideLayers = function() {
    return NFProject.toggleGuideLayers();
  };
  convertShapeToHighlight = function() {
    var key, lineCount, newColor, newName, ref, ref1, selectedLayer, testColor;
    app.beginUndoGroup("Convert Shape to Highlight");
    selectedLayer = (ref = NFProject.selectedLayers()) != null ? ref.get(0) : void 0;
    if (!((selectedLayer != null) && selectedLayer instanceof NFShapeLayer)) {
      return alert("No Valid Shape Layer Selected");
    }
    lineCount = parseInt(prompt('How many initial highlight lines would you like to create?'));
    newName = selectedLayer.getName().replace("Imported PDF Shape: ", "");
    ref1 = NFHighlightLayer.COLOR;
    for (key in ref1) {
      testColor = ref1[key];
      if (newName.indexOf(testColor.str) >= 0) {
        newColor = testColor;
      }
    }
    selectedLayer.containingComp().createHighlight({
      shapeLayer: selectedLayer,
      lines: lineCount,
      name: newName,
      color: newColor != null ? newColor : NFHighlightLayer.COLOR.YELLOW
    });
    selectedLayer.remove();
    return app.endUndoGroup();
  };
  deleteHighlightAtIndex = function(idx) {
    var targetComp;
    app.beginUndoGroup("Delete Highlight");
    idx = parseInt(idx);
    targetComp = NFProject.activeComp();
    targetComp.$.layer(idx).remove();
    return app.endUndoGroup();
  };
  splitHighlightAtIndex = function(idx) {
    var targetComp, targetLayer;
    app.beginUndoGroup("Split Highlight");
    idx = parseInt(idx);
    targetComp = NFProject.activeComp();
    targetLayer = new NFHighlightLayer(targetComp.$.layer(idx));
    targetLayer.split();
    return app.endUndoGroup();
  };
  addGaussy = function() {
    app.beginUndoGroup("Add Gaussy");
    NFProject.activeComp().addGaussy();
    return app.endUndoGroup();
  };
  addBrowser = function() {
    var activeComp;
    app.beginUndoGroup("Add Browser");
    activeComp = NFProject.activeComp();
    activeComp.addBrowserWindow(activeComp.selectedLayers());
    return app.endUndoGroup();
  };
  unlinkHighlightAtIndex = function(idx) {
    var targetComp, targetLayer;
    app.beginUndoGroup("Unlink Highlight");
    idx = parseInt(idx);
    targetComp = NFProject.activeComp();
    targetLayer = new NFHighlightLayer(targetComp.$.layer(idx));
    targetLayer.effects().property("Rect Hash").remove();
    return app.endUndoGroup();
  };
  changeLineCountForHighlightAtIndex = function(idx, delta) {
    var targetComp, targetLayer;
    app.beginUndoGroup("Change Line Count");
    idx = parseInt(idx);
    delta = parseInt(delta);
    targetComp = NFProject.activeComp();
    targetLayer = new NFHighlightLayer(targetComp.$.layer(idx));
    targetLayer.changeLineCount(delta);
    return app.endUndoGroup();
  };
  createHighlightFromAnnotation = function(annotationDataString) {
    var annotData, annotationLayer, key, newColor, ref, targetComp, testColor;
    app.beginUndoGroup("Create Highlight from Annotation");
    annotData = JSON.parse(annotationDataString);
    targetComp = NFProject.activeComp();
    annotationLayer = targetComp.addShapeLayer();
    annotationLayer.addRectangle({
      fillColor: annotData.color,
      rect: annotData.rect
    });
    annotationLayer.transform().scale.setValue(targetComp != null ? targetComp.getPDFLayer().transform().scale.value : void 0);
    if (annotData.lineCount === 0) {
      annotationLayer.transform("Opacity").setValue(20);
      annotationLayer.setName("Imported PDF Shape: " + annotData.cleanName);
    } else {
      ref = NFHighlightLayer.COLOR;
      for (key in ref) {
        testColor = ref[key];
        if (annotData.colorName.indexOf(testColor.str) >= 0) {
          newColor = testColor;
        }
      }
      targetComp.createHighlight({
        shapeLayer: annotationLayer,
        lines: annotData.lineCount,
        name: annotData.cleanName,
        color: newColor,
        rectHash: annotData.rectHash
      });
      annotationLayer.remove();
    }
    return app.endUndoGroup();
  };
  linkHighlightToSelectedLayer = function(annotationDataString) {
    var annotData, hashProp, rectHash, selectedLayers, targetComp;
    app.beginUndoGroup("Link Existing Highlight to Annotation");
    annotData = JSON.parse(annotationDataString);
    targetComp = NFProject.activeComp();
    selectedLayers = targetComp.selectedLayers();
    if (selectedLayers.count() === 1 && selectedLayers.get(0) instanceof NFHighlightLayer) {
      rectHash = annotData.rectHash;
      hashProp = selectedLayers.get(0).addEffect('ADBE Point Control');
      hashProp.property("Point").setValue(rectHash);
      hashProp.name = "Rect Hash";
    } else {
      alert("Error: Please try again with a single highlight layer selected.");
    }
    return app.endUndoGroup();
  };
  clearFMFTransition = function() {
    app.beginUndoGroup("Clear FMF Transitions");
    NFProject.activeComp().selectedLayers().forEach((function(_this) {
      return function(theLayer) {
        var ref, ref1, ref2;
        if ((ref = theLayer.effect("Transition Type")) != null) {
          ref.remove();
        }
        if ((ref1 = theLayer.effect("Position Override")) != null) {
          ref1.remove();
        }
        if ((ref2 = theLayer.effect("Scale Override")) != null) {
          ref2.remove();
        }
        theLayer.removeNFMarkers();
        return theLayer.transform("Position").expression = "";
      };
    })(this));
    return app.endUndoGroup();
  };
  applyFMFTransition = function(options) {
    var dropdownItems, mainComp, selectedLayers, slide1, slide2, transitionDuration;
    app.beginUndoGroup("FMF Transition");
    dropdownItems = ['Fullscreen', 'Splitscreen', 'Custom'];
    transitionDuration = 1;
    mainComp = NFProject.activeComp();
    selectedLayers = mainComp.selectedLayers();
    switch (selectedLayers.count()) {
      case 0:
        alert("Error: No layer selected");
        break;
      case 1:
      case 2:
        if (selectedLayers.count() === 2) {
          if (options.slide === false) {
            alert("Error: Two layers selected but slide wasn't chosen");
          } else {
            if (selectedLayers.get(0).$.inPoint < selectedLayers.get(1).$.inPoint) {
              slide1 = selectedLayers.get(0);
              slide2 = selectedLayers.get(1);
            } else {
              slide1 = selectedLayers.get(1);
              slide2 = selectedLayers.get(0);
            }
            if (slide2.$.inPoint + mainComp.$.frameDuration >= slide1.$.outPoint) {
              slide2.$.startTime = slide2.$.startTime - transitionDuration / 2;
              slide2.$.outPoint = slide2.$.outPoint + transitionDuration / 2;
              slide1.$.outPoint = slide1.$.outPoint + transitionDuration / 2;
            }
          }
        }
        selectedLayers.forEach((function(_this) {
          return function(slideLayer) {
            var dropdownEffect, offscreenPosEndValue, offscreenPosStartValue, posProp, positionOverride, scaleOverride, slideEffects, temp;
            slideEffects = slideLayer.effects();
            if (slideEffects.property("Transition Type") == null) {
              dropdownEffect = slideEffects.addProperty('ADBE Dropdown Control');
              temp = dropdownEffect.property(1).setPropertyParameters(dropdownItems);
              temp.propertyGroup(1).name = "Transition Type";
              temp.setValue(options.footageType + 1);
              positionOverride = slideEffects.addProperty('ADBE Point Control');
              positionOverride.property(1).setValue([960, 540]);
              positionOverride.name = "Position Override";
              scaleOverride = slideEffects.addProperty('ADBE Slider Control');
              scaleOverride.property(1).setValue(100);
              scaleOverride.name = "Scale Override";
            }
            posProp = slideLayer.transform("Position");
            if (options.slide) {
              offscreenPosStartValue = [posProp.value[0] + slideLayer.$.width, posProp.value[1], 0];
              offscreenPosEndValue = [posProp.value[0] - slideLayer.$.width, posProp.value[1], 0];
              if (selectedLayers.count() === 2) {
                if (slideLayer.is(slide1)) {
                  options.out = true;
                  options["in"] = false;
                } else {
                  options["in"] = true;
                  options.out = false;
                }
              }
            } else {
              offscreenPosStartValue = offscreenPosEndValue = [posProp.value[0], posProp.value[1] + slideLayer.$.height, 0];
            }
            return slideLayer.addInOutMarkersForProperty({
              property: posProp,
              length: transitionDuration,
              startEquation: options["in"] ? EasingEquation.quint.inOut : null,
              endEquation: options.out ? EasingEquation.quint.inOut : null,
              startValue: options["in"] ? offscreenPosStartValue : null,
              endValue: options.out ? offscreenPosEndValue : null
            });
          };
        })(this));
        break;
      default:
        alert("Error: Too many layers selected");
    }
    return app.endUndoGroup();
  };
} catch (error) {
  e = error;
  alert(e);
}
