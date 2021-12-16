$(document).ready(function() {
  var MAX_POLLING_ITERATIONS, NFClass, POLLING_INTERVAL, POLLING_TIMEOUT, checkForUpdates, colorPicker, compLayerType, csInterface, currentSettings, defaultSettings, displayError, empColorPickButton, extensionDirectory, getPageAnnotations, getPollingData, hook, isChangingValue, latestAnnotationData, loadEmphasisPane, loadLayoutPane, loadToolTab, pickerActive, populateSettingsPanelFromFile, rectHash, rgbToHex, rgbToRGBA255, rgbaToFloatRGB, smartTimer, timerCounter;
  csInterface = new CSInterface;
  csInterface.requestOpenExtension('com.my.localserver', '');
  hook = function(hookString, callback) {
    if (callback == null) {
      callback = null;
    }
    return csInterface.evalScript(hookString, callback);
  };
  hook("var i, len, nfInclude, path, includePaths; var includePaths = $.includePath.split(';'); for (i = 0, len = includePaths.length; i < len; i++) { path = includePaths[i]; if (path.indexOf('jl_pdf_manager') >= 0) { nfInclude = path; } } $.evalFile(nfInclude + '/../lib/nf_tools/build/runtimeLibraries.jsx');");
  latestAnnotationData = {};
  smartTimer = null;
  POLLING_INTERVAL = 1000;
  POLLING_TIMEOUT = 25000;
  MAX_POLLING_ITERATIONS = 3600;
  NFClass = {
    Comp: "NFComp",
    PartComp: "NFPartComp",
    PageComp: "NFPageComp",
    Layer: "NFLayer",
    PageLayer: "NFPageLayer",
    CitationLayer: "NFCitationLayer",
    GaussyLayer: "NFGaussyLayer",
    EmphasisLayer: "NFEmphasisLayer",
    HighlightLayer: "NFHighlightLayer",
    HighlightControlLayer: "NFHighlightControlLayer",
    ShapeLayer: "NFShapeLayer",
    ReferencePageLayer: "NFReferencePageLayer"
  };
  timerCounter = 0;
  defaultSettings = {
    edgePadding: 80,
    bottomPadding: 150,
    maskExpansion: 26,
    transforms: {
      page: {
        scale: {
          large: 40,
          small: 17
        },
        position: {
          large: [960, 1228.2],
          small: [1507, 567]
        }
      }
    },
    constraints: {
      fst: {
        width: 80,
        top: 18
      }
    },
    expose: {
      maxScale: 100,
      fillPercentage: 90
    },
    durations: {
      pageShrink: 1.2,
      pageGrow: 1.2,
      refTransition: 0.6,
      expandTransition: 0.7,
      fadeIn: 0.5,
      slideIn: 1.5,
      slideOut: 0.8,
      multiEndOffset: 0.3
    }
  };
  rgbToHex = function(r, g, b) {
    var componentToHex;
    componentToHex = function(c) {
      var hex;
      hex = c.toString(16);
      if (hex.length === 1) {
        return '0' + hex;
      } else {
        return hex;
      }
    };
    if (r.length === 3) {
      b = r[2];
      g = r[1];
      r = r[0];
    }
    return '#' + componentToHex(r) + componentToHex(g) + componentToHex(b);
  };
  rgbaToFloatRGB = function(arr) {
    return [arr[0] / 255, arr[1] / 255, arr[2] / 255];
  };
  rgbToRGBA255 = function(arr) {
    return [Math.round(arr[0] * 255), Math.round(arr[1] * 255), Math.round(arr[2] * 255)];
  };
  displayError = function(message) {
    var $bar;
    $bar = $('#error-bar');
    $bar.text("ERROR: " + message);
    return $bar.show();
  };
  rectHash = function(rect) {
    return [Math.floor(rect.height * 31 + rect.width), Math.floor(rect.top * 31 + rect.left)];
  };
  $('#error-bar').click(function() {
    return $(this).hide();
  });
  currentSettings = {};
  populateSettingsPanelFromFile = function() {
    return hook("editDefaultsFile()", function(res) {
      var addSettingsItem, k, mainList, mainSettingsList, settingsContent, v;
      if (res === "") {
        hook("editDefaultsFile(" + (JSON.stringify(defaultSettings)) + ")");
        settingsContent = defaultSettings;
      } else {
        settingsContent = JSON.parse(res);
      }
      addSettingsItem = function(name, value, destination) {
        var dataVal, listItem, newSettingsItem, results, subKey, subList, subVal, textBox;
        if (typeof value === 'object' && value !== null) {
          listItem = $("<li></li>");
          destination.append(listItem);
          dataVal = {
            name: name,
            value: value
          };
          listItem.data(dataVal);
          subList = $("<ul><p>" + name + "</p></ul>");
          listItem.append(subList);
          results = [];
          for (subKey in value) {
            subVal = value[subKey];
            results.push(addSettingsItem(subKey, subVal, subList));
          }
          return results;
        } else {
          textBox = $("<input type='text' placeholder='" + name + "' value='" + value + "'></input><label>" + name + "</label>");
          newSettingsItem = $("<li></li>").append(textBox);
          dataVal = {
            name: name,
            value: value
          };
          newSettingsItem.data(dataVal);
          return destination.append(newSettingsItem);
        }
      };
      $("#settings-options").html("");
      mainList = $("<ul></ul>");
      mainSettingsList = $("#settings-options").append(mainList);
      for (k in settingsContent) {
        v = settingsContent[k];
        addSettingsItem(k, v, mainList);
      }
      return currentSettings = settingsContent;
    });
  };
  getPageAnnotations = function() {
    var annotationDate, disp;
    disp = $("#annotation-display");
    annotationDate = new Date();
    console.log("getPageAnnotations()");
    return hook("app.project", function(res) {
      if (res != null) {
        return hook("getActivePageFile()", function(result) {
          var url;
          console.log("annotation hook returned - " + (new Date() - annotationDate) + "ms");
          console.log(result);
          if (result !== "null" && result !== "" && result !== null) {
            url = 'http://localhost:3200/annotationData';
            return $.ajax({
              type: 'GET',
              url: url,
              data: {
                filepath: result
              },
              success: function(response) {
                var annotHash, annotation, annotationDataString, colorClassName, dispElement, dispID, existingHighlights, highlightLayer, i, j, l, len, len1, m, matchClass, results;
                if (JSON.stringify(response) === JSON.stringify(latestAnnotationData)) {

                } else {
                  latestAnnotationData = response;
                  disp.empty();
                  if (response.length === 0) {
                    return disp.append("<p class='no-annotations-found'>No annotations found in this PDF</p>");
                  } else {
                    console.log(response);
                    results = [];
                    for (i = l = 0, len = response.length; l < len; i = ++l) {
                      annotation = response[i];
                      annotHash = rectHash(annotation.rect);
                      matchClass = "";
                      existingHighlights = $('body').data().highlightLayers;
                      for (j = m = 0, len1 = existingHighlights.length; m < len1; j = ++m) {
                        highlightLayer = existingHighlights[j];
                        if (highlightLayer.rectHash != null) {
                          if (highlightLayer.rectHash[0] === annotHash[0] && highlightLayer.rectHash[1] === annotHash[1]) {
                            matchClass = "match-" + highlightLayer.index + " matched";
                          }
                        }
                      }
                      dispID = "annotation-" + annotHash[0] + "-" + annotHash[1];
                      colorClassName = annotation.colorName.replace(/\s+/g, '-').toLowerCase();
                      disp.append("<li id='" + dispID + "' class='annotation-item " + colorClassName + " " + matchClass + "'></li>");
                      dispElement = $("#" + dispID);
                      dispElement.append("<div class='clean-name'>" + annotation.cleanName + "</div> <div class='highlight-text'>" + annotation.text + "</div>");
                      annotation.rectHash = annotHash;
                      annotationDataString = JSON.stringify(annotation);
                      dispElement.data(annotationDataString);
                      if (matchClass.indexOf('matched') >= 0) {
                        dispElement.append("<div class='action-buttons'> <div class='button-group'> <div class='delete'></div> </div> <div class='button-group'> <div class='add-line'></div> <div class='remove-line'></div> </div> <div class='button-group'> <div class='unlink'></div> </div> </div>");
                        dispElement.find('.delete').click({}, function(e) {
                          var classNames, theExp, theIdx;
                          classNames = $(this).parent().parent().parent().attr('class');
                          theExp = /match-(.*?)[\s]/g;
                          theIdx = parseInt(theExp.exec(classNames)[1]);
                          return hook("deleteHighlightAtIndex('" + theIdx + "')");
                        });
                        dispElement.find('.add-line').click({
                          param: annotationDataString
                        }, function(e) {
                          var classNames, theExp, theIdx;
                          classNames = $(this).parent().parent().parent().attr('class');
                          theExp = /match-(.*?)[\s]/g;
                          theIdx = parseInt(theExp.exec(classNames)[1]);
                          return hook("changeLineCountForHighlightAtIndex('" + theIdx + "', '1')");
                        });
                        dispElement.find('.remove-line').click({
                          param: annotationDataString
                        }, function(e) {
                          var classNames, theExp, theIdx;
                          classNames = $(this).parent().parent().parent().attr('class');
                          theExp = /match-(.*?)[\s]/g;
                          theIdx = parseInt(theExp.exec(classNames)[1]);
                          return hook("changeLineCountForHighlightAtIndex('" + theIdx + "', '-1')");
                        });
                        results.push(dispElement.find('.unlink').click({}, function(e) {
                          var classNames, theExp, theIdx;
                          classNames = $(this).parent().parent().parent().attr('class');
                          theExp = /match-(.*?)[\s]/g;
                          theIdx = parseInt(theExp.exec(classNames)[1]);
                          return hook("unlinkHighlightAtIndex('" + theIdx + "')");
                        }));
                      } else {
                        dispElement.append("<div class='action-buttons'> <div class='button-group'> <div class='add-magic'></div> </div> <div class='button-group'> <div class='add-manual'></div> </div> <div class='button-group'> <div class='link-existing'></div> </div> </div>");
                        dispElement.find('.add-magic').click({
                          param: annotationDataString
                        }, function(e) {
                          return hook("createHighlightFromAnnotation('" + e.data.param + "')");
                        });
                        dispElement.find('.add-manual').click({
                          param: annotationDataString
                        }, function(e) {
                          return hook("prompt('How many lines?')", function(res) {
                            var lineCount, param;
                            param = JSON.parse(e.data.param);
                            lineCount = parseInt(res);
                            if (isNaN(lineCount)) {
                              return alert("Error:\nThe value entered ('" + res + "') is not a valid integer.");
                            } else {
                              param.lineCount = lineCount;
                              return hook("createHighlightFromAnnotation('" + (JSON.stringify(param)) + "')");
                            }
                          });
                        });
                        results.push(dispElement.find('.link-existing').click({
                          param: annotationDataString
                        }, function(e) {
                          return hook("linkHighlightToSelectedLayer('" + e.data.param + "')");
                        }));
                      }
                    }
                    return results;
                  }
                }
              },
              error: function(jqXHR, textStatus, errorThrown) {
                console.log("Error: " + errorThrown + ", " + jqXHR.responseJSON);
                disp.empty();
                disp.append("<p class='error-thrown'>The PDF Server returned an error. 🤷Talk to Jesse...</p>");
                return latestAnnotationData = {};
              }
            });
          } else {
            disp.empty();
            disp.append("<p class='no-active-page'>No active page</p>");
            return latestAnnotationData = {};
          }
        });
      } else {
        disp.empty();
        disp.append("<p class='no-active-project'>No active project</p>");
        return latestAnnotationData = {};
      }
    });
  };
  compLayerType = "";
  timerCounter = 0;
  checkForUpdates = function() {
    if (timerCounter >= MAX_POLLING_ITERATIONS) {
      console.log("threshold reached - stopping smart updates");
      timerCounter = 0;
      return $('#smart-toggle').click();
    } else {
      return getPollingData();
    }
  };
  getPollingData = function() {
    var startInterval;
    console.log("polling (" + (smartTimer != null ? timerCounter : "one-time") + ")...");
    startInterval = new Date();
    return hook("getPollingData()", function(res) {
      var data, requestTime;
      requestTime = new Date() - startInterval;
      console.log("polling data returned (" + (smartTimer != null ? timerCounter : "one-time") + ") - " + requestTime + "ms");
      if (res == null) {
        return console.log("empty result!");
      }
      if (requestTime > POLLING_TIMEOUT && (smartTimer != null)) {
        timerCounter = 0;
        $('#smart-toggle').click();
        return console.log("turning off smart updates - request took too long");
      }
      if (res.length === 0) {
        displayError("got nothing back from polling hook!");
        return $("body").removeClass();
      } else {
        if (res !== "undefined") {
          data = JSON.parse(res);
          if (compLayerType !== data.bodyClass) {
            compLayerType = data.bodyClass;
            $("body").removeClass();
            $("body").addClass(compLayerType);
          }
          $("body").data(data);
          timerCounter++;
          if (compLayerType.indexOf(NFClass.PageComp) >= 0) {
            getPageAnnotations();
          }
          if (compLayerType.indexOf(NFClass.EmphasisLayer) >= 0) {
            loadEmphasisPane();
          }
          if (compLayerType.indexOf(NFClass.PartComp) >= 0) {
            return loadLayoutPane();
          }
        }
      }
    });
  };
  $('#reload-button').click(function() {
    if (smartTimer != null) {
      clearInterval(smartTimer);
    }
    hook("var i, len, nfInclude, path, includePaths; var includePaths = $.includePath.split(';'); for (i = 0, len = includePaths.length; i < len; i++) { path = includePaths[i]; if (path.indexOf('jl_pdf_manager') >= 0) { nfInclude = path; } } $.evalFile(nfInclude + '/../host/hooks.jsx');");
    return window.location.reload(true);
  });
  $('#smart-toggle').click(function() {
    if (smartTimer != null) {
      $("#smart-toggle").removeClass("running");
      $('#one-page-annotations').removeClass("disabled");
      clearInterval(smartTimer);
      return smartTimer = null;
    } else {
      $("#smart-toggle").addClass("running");
      $('#one-page-annotations').addClass("disabled");
      return smartTimer = setInterval(checkForUpdates, POLLING_INTERVAL);
    }
  });
  $('#smart-toggle').click();
  $('#single-fetch').click(function() {
    return getPollingData();
  });
  $('#convert-shape').click(function() {
    return hook("convertShapeToHighlight()");
  });
  $('#classic-highlight').click(function() {
    return hook("NFTools.evalFile('nf_SetupHighlightLayer.jsx')");
  });
  $('#tool-panel').click(function() {
    $('.tab').removeClass("active");
    return $('.tab.tool-panel').addClass("active");
  });
  $('#settings-tab-button').click(function() {
    $('.tab').removeClass("active");
    $('.tab.settings').addClass("active");
    return populateSettingsPanelFromFile();
  });
  $('#save-settings').click(function() {
    var getElementsInUL, newSettingsObj;
    getElementsInUL = function(ul) {
      var retObj;
      retObj = {};
      ul.children("li").each(function(i) {
        var assemblyArr, subList;
        subList = $(this).children("ul");
        if (subList.length) {
          if ($(this).data().value instanceof Array) {
            assemblyArr = [];
            subList.children("li").each(function(i) {
              return assemblyArr.push(parseFloat($(this).children("input").val()));
            });
            return retObj[$(this).data().name] = assemblyArr;
          } else {
            return retObj[$(this).data().name] = getElementsInUL(subList);
          }
        } else {
          return retObj[$(this).data().name] = parseFloat($(this).children("input").val());
        }
      });
      return retObj;
    };
    newSettingsObj = getElementsInUL($("#settings-options > ul"));
    hook("editDefaultsFile(" + (JSON.stringify(newSettingsObj)) + ")");
    return currentSettings = newSettingsObj;
  });
  $('#reset-changes').click(function() {
    return populateSettingsPanelFromFile();
  });
  $('#restore-all-settings').click(function() {
    hook("editDefaultsFile('')");
    return populateSettingsPanelFromFile();
  });
  $('#toggle-guides').click(function() {
    return hook("toggleGuideLayers()");
  });
  $('#shy-show-all').click(function() {
    return hook("focusOn('all')");
  });
  $('#shy-focus-pdf').click(function() {
    return hook("focusOn('pdf')");
  });
  $('#shy-focus-active').click(function() {
    return hook("focusOn('active')");
  });
  $("#out-transition .nf-fade").click(function() {
    return hook("transitionFadeOut()");
  });
  $("#in-transition .nf-fade").click(function() {
    return hook("transitionFadeIn()");
  });
  $("#out-transition .nf-slide").click(function() {
    return hook("transitionSlideOut()");
  });
  $("#in-transition .nf-slide").click(function() {
    return hook("transitionSlideIn()");
  });
  $("#out-transition .nf-fade-scale").click(function() {
    return hook("transitionFadeScaleOut()");
  });
  $("#in-transition .nf-fade-scale").click(function() {
    return hook("transitionFadeScaleIn()");
  });
  $("#out-transition .clear").click(function() {
    return hook("transitionClearOut()");
  });
  $("#in-transition .clear").click(function() {
    return hook("transitionClearIn()");
  });
  $("button.emphasizer-button").click(function() {
    return hook("emphasisLayerSelected()", function(res) {
      if (res === "true") {
        return hook("NFTools.evalFile('nf_Emphasizer.jsx')");
      } else {
        return hook("makeEmphasisLayer()");
      }
    });
  });
  $("button.gaussy-button").click(function() {
    return hook("addGaussy()", function(res) {
      return null;
    });
  });
  $("button.browser-button").click(function() {
    return hook("addBrowser()", function(res) {
      return null;
    });
  });
  $("button.blend-button").click(function() {
    return $('#blend-menu').toggle();
  });
  $('#blend-screen-button').click(function() {
    $('#blend-menu').toggle();
    return hook("setBlendingMode('screen')");
  });
  $('#blend-normal-button').click(function() {
    $('#blend-menu').toggle();
    return hook("setBlendingMode('normal')");
  });
  $('#blend-multiply-button').click(function() {
    $('#blend-menu').toggle();
    return hook("setBlendingMode('multiply')");
  });
  $('#blend-overlay-button').click(function() {
    $('#blend-menu').toggle();
    return hook("setBlendingMode('overlay')");
  });
  isChangingValue = false;
  $('#emphasizer-panel .slider-container input').on("pointerdown", function() {
    return isChangingValue = true;
  });
  $('#emphasizer-panel .slider-container input').change(function() {
    var emphParams, thicknessValue;
    isChangingValue = false;
    $(this).siblings(".value").text($(this).val());
    if ($(this).is("#thickness-slider")) {
      thicknessValue = $(this).val();
      emphParams = {
        name: $('#emphasis-list li.active').data().name,
        thickness: thicknessValue
      };
      return hook("setEmphasisProperties('" + (JSON.stringify(emphParams)) + "')");
    }
  });
  $('#emphasis-list').on('click', 'li', function() {
    $('#emphasis-list li.active').removeClass('active');
    $(this).addClass('active');
    return loadEmphasisPane();
  });
  $('#emphasizer-panel button.apply-to-all').click(function() {
    var effects, emphParams, item, l, len;
    effects = $('body').data().effects;
    for (l = 0, len = effects.length; l < len; l++) {
      item = effects[l];
      emphParams = {
        name: item.name,
        color: $('#emphasis-list li.active').data().properties.Color.value
      };
      hook("setEmphasisProperties('" + (JSON.stringify(emphParams)) + "')");
    }
    return loadEmphasisPane();
  });
  loadEmphasisPane = function() {
    var $activeItem, $list, $thicknessSlider, $title, activeItemName, bullet, bulletColor, data, dataColor, dataThickness, effect, i, l, len, newItem, oldTitle, ref, rgbString, rgba225Color, sameLayer;
    data = $('body').data();
    sameLayer = false;
    $title = $("#emphasis-title");
    oldTitle = $title.text();
    if (oldTitle === data.selectedLayers[0]) {
      sameLayer = true;
    } else {
      $title.text(data.selectedLayers[0]);
    }
    $list = $('#emphasis-list');
    if (sameLayer) {
      $activeItem = $list.find('li.active');
      if (($activeItem != null) && ($activeItem.data() != null)) {
        activeItemName = $activeItem.data().name;
      } else {
        activeItemName = null;
      }
    }
    $list.empty();
    if (data.effects.length !== 0) {
      ref = data.effects;
      for (i = l = 0, len = ref.length; l < len; i = ++l) {
        effect = ref[i];
        newItem = $("<li>" + effect.name + "</li>").appendTo($list);
        newItem.data(effect);
        if ((i === 0 && (activeItemName == null)) || (effect.name === activeItemName)) {
          newItem.addClass("active");
        }
        bullet = $("<span class='bullet'>&#9632;</span>").prependTo(newItem);
        bulletColor = rgbToHex(rgbToRGBA255(effect.properties.Color.value.slice(0, 3)));
        bullet.css("color", bulletColor);
      }
    } else {
      $list.append("<li class='none'>No Emphasizers</li>");
    }
    if (data.effects.length !== 0) {
      dataColor = $list.find('li.active').data().properties.Color.value;
      rgba225Color = rgbToRGBA255(dataColor);
      rgbString = "rgb(" + rgba225Color[0] + ", " + rgba225Color[1] + ", " + rgba225Color[2] + ")";
      if (!pickerActive) {
        empColorPickButton.css({
          'background-color': rgbString
        });
      }
      if (!isChangingValue) {
        dataThickness = $list.find('li.active').data().properties.Thickness.value;
        $thicknessSlider = $('#thickness-slider');
        $thicknessSlider.val(dataThickness);
        return $thicknessSlider.siblings(".value").text(dataThickness);
      }
    }
  };
  empColorPickButton = $('#emphasizer-panel .color-field');
  colorPicker = new Picker(empColorPickButton[0]);
  pickerActive = false;
  colorPicker.setOptions({
    popup: "top",
    alpha: false,
    color: empColorPickButton.css("background-color"),
    onOpen: function(color) {
      pickerActive = true;
      return colorPicker.setColor(empColorPickButton.css('background-color'));
    },
    onChange: function(color) {
      return empColorPickButton.css({
        'background-color': color.rgbaString
      });
    },
    onDone: function(color) {
      var emphParams;
      empColorPickButton.css({
        'background-color': color.rgbaString
      });
      emphParams = {
        name: $('#emphasis-list li.active').data().name,
        color: rgbaToFloatRGB(color.rgba)
      };
      return hook("setEmphasisProperties('" + (JSON.stringify(emphParams)) + "')");
    },
    onClose: function(color) {
      pickerActive = false;
      return loadEmphasisPane();
    }
  });
  loadToolTab = function() {
    var $tools, toolRegistry;
    $tools = $("#tool-panel-tools");
    toolRegistry = null;
    return hook("JSON.stringify(toolRegistry)", function(res) {
      var $newCategoryList, $newListItem, category, key, results, thisTool, toolKey;
      if (res === "") {
        return $('#tool-panel').addClass('disabled');
      } else {
        $('#tool-panel').removeClass('disabled');
        toolRegistry = JSON.parse(res);
        results = [];
        for (key in toolRegistry) {
          category = toolRegistry[key];
          $("<h3>" + category.name + "</h3>").appendTo($tools);
          $newCategoryList = $("<ul class='category-list'></ul>").appendTo($tools);
          results.push((function() {
            var results1;
            results1 = [];
            for (toolKey in category.tools) {
              thisTool = category.tools[toolKey];
              $newListItem = $("<li class='tool-item'>" + thisTool.name + "</li>").appendTo($newCategoryList);
              results1.push($newListItem.data({
                key: toolKey
              }));
            }
            return results1;
          })());
        }
        return results;
      }
    });
  };
  loadToolTab();
  populateSettingsPanelFromFile();
  $('#close-tool-panel').click(function(e) {
    $('.tab').removeClass('active');
    return $('.tab.main').addClass('active');
  });
  $('#close-settings-panel').click(function(e) {
    $('.tab').removeClass('active');
    return $('.tab.main').addClass('active');
  });
  $('#run-tool').click(function(e) {
    hook("runTool('" + ($("#tool-panel-tools li.active").data().key) + "')");
    return $("#tool-panel-tools li.active").removeClass("active");
  });
  $("#tool-panel-tools").on('click', 'li', function(e) {
    event.stopPropagation();
    $("#tool-panel-tools li").removeClass("active");
    return $(this).addClass("active");
  });
  $("#tool-panel-tools").on('dblclick', 'li', function(e) {
    event.stopPropagation();
    return $('#run-tool').click();
  });
  loadLayoutPane = function(refreshTree) {
    var $itemName, $list, data, singleLayer;
    if (refreshTree == null) {
      refreshTree = false;
    }
    data = $("body").data();
    $itemName = $('#layout-panel .active-item .item-name');
    if (data.selectedLayers.length === 0) {
      $itemName.text("No layer selected");
    } else if (data.selectedLayers.length === 1) {
      singleLayer = data.selectedLayers[0];
      $itemName.text(singleLayer.name);
    } else if (data.selectedLayers.length > 1) {
      $itemName.text("Multiple layers selected");
    }
    $('#layout-panel .active-item .item-control button').addClass('disabled');
    $('#layout-panel .active-item button.refresh-tree').removeClass('disabled');
    if ((singleLayer != null ? singleLayer["class"] : void 0) === NFClass.PageLayer) {
      $('#layout-panel .active-item button.shrink-page').removeClass('disabled');
      $('#layout-panel .active-item button.grow-page').removeClass('disabled');
      $('#layout-panel .active-item button.end-element').removeClass('disabled');
    }
    if ((singleLayer != null ? singleLayer["class"] : void 0) === NFClass.ReferencePageLayer || data.selectedLayers.length > 1) {
      $('#layout-panel .active-item button.re-anchor').removeClass('disabled');
      $('#layout-panel .active-item button.end-element').removeClass('disabled');
    }
    if ((singleLayer != null ? singleLayer["class"] : void 0) === NFClass.Layer || (singleLayer != null ? singleLayer["class"] : void 0) === NFClass.GaussyLayer) {
      $('#layout-panel .active-item button.end-element').removeClass('disabled');
    }
    $list = $("#selector-list");
    if ($list.children().length === 0 || refreshTree === true) {
      $list.empty();
      return hook("getFullPDFTree()", function(res) {
        var $newPDFItem, $newPageItem, $newShapeItem, $pageList, $shapeList, l, len, pageItem, pdfItem, ref, results, selectorData, shapeItem;
        if (typeof res === "string") {
          if (res.indexOf("Error") > -1) {
            hook("alert('Error getting PDF tree:" + res + "')");
            if (smartTimer != null) {
              $('#smart-toggle').click();
            }
          }
        }
        selectorData = JSON.parse(res);
        ref = selectorData.pdfs;
        results = [];
        for (l = 0, len = ref.length; l < len; l++) {
          pdfItem = ref[l];
          $newPDFItem = $("<li class='pdf-item'><span>" + (pdfItem.name.slice(4)) + "</span></li>").appendTo($list);
          $newPDFItem.data(pdfItem);
          $pageList = $("<ul></ul>").appendTo($newPDFItem);
          results.push((function() {
            var len1, m, ref1, results1;
            ref1 = pdfItem.pages;
            results1 = [];
            for (m = 0, len1 = ref1.length; m < len1; m++) {
              pageItem = ref1[m];
              $newPageItem = $("<li class='page-item'><span>" + (pageItem.name.substring(pageItem.name.lastIndexOf('pg') + 2, pageItem.name.lastIndexOf(' '))) + "</span></li>").appendTo($pageList);
              $newPageItem.data(pageItem);
              if (pageItem.shapes.length > 0) {
                $shapeList = $("<ul></ul>").appendTo($newPageItem);
                results1.push((function() {
                  var len2, n, ref2, results2;
                  ref2 = pageItem.shapes;
                  results2 = [];
                  for (n = 0, len2 = ref2.length; n < len2; n++) {
                    shapeItem = ref2[n];
                    $newShapeItem = $("<li class='shape-item'><span>" + shapeItem.name + "</span></li>").appendTo($shapeList);
                    results2.push($newShapeItem.data(shapeItem));
                  }
                  return results2;
                })());
              } else {
                results1.push(void 0);
              }
            }
            return results1;
          })());
        }
        return results;
      });
    }
  };
  $('#selector-list').on('click', 'li', function(event) {
    var targetClass, targetData;
    event.stopPropagation();
    if ($(this).hasClass('collapsed')) {
      $(this).removeClass('collapsed');
    } else {
      $(this).addClass('collapsed');
    }
    if (!$(this).hasClass('active')) {
      $('#selector-list li').removeClass('active');
      targetData = $(this).data();
      targetClass = targetData["class"];
      $('#layout-panel .selector-buttons button').addClass('disabled');
      if (targetClass === NFClass.PageComp) {
        $('#layout-panel .fullscreen-title').removeClass('disabled');
        $('#layout-panel .add-small').removeClass('disabled');
        if (targetData.pdfNumber === $('body').data().activePDF && targetData.pageNumber !== $('body').data().activePage.pageNumber) {
          $('#layout-panel .switch-to-page').removeClass('disabled');
        }
      }
      if (targetClass === NFClass.ShapeLayer || targetClass === NFClass.HighlightLayer) {
        $('#layout-panel .expose').removeClass('disabled');
        $('#layout-panel .bubble-up').removeClass('disabled');
        if (targetData.name.toLowerCase().indexOf('expand') >= 0) {
          $('#layout-panel .expand').removeClass('disabled');
        }
      }
      return $(this).addClass('active');
    }
  });
  $('#selector-list').on('dblclick', 'li.page-item', function(e) {
    var targetData;
    targetData = $(this).data();
    return hook("openComp(" + (JSON.stringify(targetData)) + ")");
  });
  $('#layout-panel .refresh-tree').click(function(e) {
    if (!$(this).hasClass('disabled')) {
      return loadLayoutPane(true);
    }
  });
  $('#layout-panel .shrink-page').click(function(e) {
    var model;
    if (!$(this).hasClass('disabled')) {
      model = {
        target: $('body').data().selectedLayers,
        command: "shrink-page",
        settings: currentSettings
      };
      return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
    }
  });
  $('#layout-panel .grow-page').click(function(e) {
    var model;
    if (!$(this).hasClass('disabled')) {
      model = {
        target: $('body').data().selectedLayers,
        command: "fullscreen-title",
        settings: currentSettings
      };
      return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
    }
  });
  $('#layout-panel .re-anchor').click(function(e) {
    var model;
    if (!$(this).hasClass('disabled')) {
      model = {
        target: $('body').data().selectedLayers,
        command: "anchor",
        settings: currentSettings
      };
      return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
    }
  });
  $('#layout-panel .end-element').click(function(e) {
    var model;
    if (!$(this).hasClass('disabled')) {
      model = {
        target: $('body').data().selectedLayers,
        command: "end-element",
        settings: currentSettings
      };
      return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
    }
  });
  $('#layout-panel .fullscreen-title').click(function(e) {
    var $activeItem, model;
    if (!$(this).hasClass('disabled')) {
      $activeItem = $('#selector-list li.active');
      if (($activeItem != null ? $activeItem.data()["class"] : void 0) === NFClass.PageComp) {
        model = {
          target: $activeItem.data(),
          command: "fullscreen-title",
          settings: currentSettings
        };
        return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
      }
    }
  });
  $('#layout-panel .add-small').click(function(e) {
    var $activeItem, model;
    if (!$(this).hasClass('disabled')) {
      $activeItem = $('#selector-list li.active');
      if (($activeItem != null ? $activeItem.data()["class"] : void 0) === NFClass.PageComp) {
        model = {
          target: $activeItem.data(),
          command: "add-small",
          settings: currentSettings
        };
        return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
      }
    }
  });
  $('#layout-panel .switch-to-page').click(function(e) {
    var $activeItem, model;
    if (!$(this).hasClass('disabled')) {
      $activeItem = $('#selector-list li.active');
      if (($activeItem != null ? $activeItem.data()["class"] : void 0) === NFClass.PageComp) {
        model = {
          target: $activeItem.data(),
          command: "switch-to-page",
          settings: currentSettings
        };
        return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
      }
    }
  });
  $('#layout-panel .expose').click(function(e) {
    var $activeItem, data, model;
    if (!$(this).hasClass('disabled')) {
      $activeItem = $('#selector-list li.active');
      data = $activeItem != null ? $activeItem.data() : void 0;
      if (data["class"] === NFClass.ShapeLayer || data["class"] === NFClass.HighlightLayer) {
        model = {
          target: data,
          command: "expose",
          settings: currentSettings
        };
        return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
      }
    }
  });
  $('#layout-panel .expand').click(function(e) {
    var $activeItem, data, model;
    if (!$(this).hasClass('disabled')) {
      $activeItem = $('#selector-list li.active');
      data = $activeItem != null ? $activeItem.data() : void 0;
      if (data["class"] === NFClass.ShapeLayer || data["class"] === NFClass.HighlightLayer) {
        model = {
          target: data,
          command: "expand",
          settings: currentSettings
        };
        return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
      }
    }
  });
  $('#layout-panel .bubble-up').click(function(e) {
    var $activeItem, data, model;
    if (!$(this).hasClass('disabled')) {
      $activeItem = $('#selector-list li.active');
      data = $activeItem != null ? $activeItem.data() : void 0;
      if (data["class"] === NFClass.ShapeLayer || data["class"] === NFClass.HighlightLayer) {
        model = {
          target: data,
          command: "bubble",
          settings: currentSettings
        };
        return hook("runLayoutCommand(" + (JSON.stringify(model)) + ")");
      }
    }
  });
  return extensionDirectory = csInterface.getSystemPath('extension');
});
