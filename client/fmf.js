$(document).ready(function() {
  var MAX_POLLING_ITERATIONS, NFClass, POLLING_INTERVAL, POLLING_TIMEOUT, checkForUpdates, compLayerType, csInterface, displayError, extensionDirectory, getPollingData, hook, latestAnnotationData, rgbToHex, rgbToRGBA255, rgbaToFloatRGB, smartTimer, timerCounter;
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
  $('#error-bar').click(function() {
    return $(this).hide();
  });
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
          if (data.selectedLayers.length === 1) {
            $("#layer-name").text(data.selectedLayers[0].name);
            $("#buttons button").removeClass('disabled');
            return $("#slide-transition").addClass("disabled");
          } else if (data.selectedLayers.length === 0) {
            $("#layer-name").text("No Layer");
            return $("#buttons button").addClass('disabled');
          } else if (data.selectedLayers.length === 2) {
            $("#layer-name").text("Two Layers");
            $("#buttons button").addClass('disabled');
            return $("#slide-transition").removeClass("disabled");
          } else {
            $("#layer-name").text("Many Layers");
            return $("#buttons button").addClass('disabled');
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
  $('#fullscreen-in').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 0,
      slide: false,
      "in": true,
      out: false
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#fullscreen-both').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 0,
      slide: false,
      "in": true,
      out: true
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#fullscreen-out').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 0,
      slide: false,
      "in": false,
      out: true
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#splitscreen-in').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 1,
      slide: false,
      "in": true,
      out: false
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#splitscreen-both').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 1,
      slide: false,
      "in": true,
      out: true
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#splitscreen-out').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 1,
      slide: false,
      "in": false,
      out: true
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#slide-in').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 0,
      slide: true,
      "in": true,
      out: false
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#slide-both').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 0,
      slide: true,
      "in": true,
      out: true
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#slide-out').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 0,
      slide: true,
      "in": false,
      out: true
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#slide-transition').click(function() {
    var options;
    if ($(this).hasClass('disabled')) {
      return null;
    }
    options = {
      footageType: 0,
      slide: true,
      "in": true,
      out: true
    };
    return hook("applyFMFTransition(" + (JSON.stringify(options)) + ")");
  });
  $('#erase-transitions').click(function() {
    if ($(this).hasClass('disabled')) {
      return null;
    }
    return hook("clearFMFTransition()");
  });
  return extensionDirectory = csInterface.getSystemPath('extension');
});
