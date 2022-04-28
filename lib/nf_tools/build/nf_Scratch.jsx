var allParts, existingComment, i, instructionArray, instructionFile, instructionString, j, k, len, len1, lineWrap, markers, maxWordsPerMarker, minFrequency, nearestMarkerIdx, nearestMarkerTime, part, skipNext, theTime, theWord, word, wordCount, wordLayer;

$.evalFile(File($.fileName).path + "/runtimeLibraries.jsx");

app.beginUndoGroup('Run Scratch Script');

instructionFile = "transcript.csv";

if (!NFTools.testProjectFile(instructionFile)) {
  throw new Error("Cannot read " + instructionFile);
}

instructionString = NFTools.readProjectFile(instructionFile);

instructionArray = instructionString.splitCSV();

allParts = NFProject.allPartComps();

lineWrap = "...\n";

for (j = 0, len = allParts.length; j < len; j++) {
  part = allParts[j];
  wordLayer = part.addSolid({
    color: [0, 1, 0.2],
    name: "Words"
  });
  wordLayer.moveBefore(part.allLayers().getBottommostLayer());
  wordLayer.$.guideLayer = true;
  wordLayer.$.enabled = false;
  markers = wordLayer.markers();
  maxWordsPerMarker = 3;
  minFrequency = 1;
  skipNext = false;
  for (i = k = 0, len1 = instructionArray.length; k < len1; i = ++k) {
    word = instructionArray[i];
    if (i !== 0) {
      theTime = parseFloat(word[0]);
      if (!isNaN(theTime)) {
        theWord = word[1];
        if (markers.numKeys > 0) {
          nearestMarkerIdx = markers.nearestKeyIndex(theTime);
          nearestMarkerTime = markers.keyTime(nearestMarkerIdx);
          if (nearestMarkerTime === theTime || theTime - nearestMarkerTime < minFrequency) {
            theTime = nearestMarkerTime;
            existingComment = markers.keyValue(nearestMarkerIdx).comment;
            wordCount = existingComment.split(' ').length;
            if (wordCount === maxWordsPerMarker) {
              theWord = existingComment;
              if (!(theWord.indexOf("...") >= 0)) {
                theWord += "...";
              }
            } else if (wordCount < maxWordsPerMarker) {
              theWord = existingComment + " " + theWord;
            }
          }
        }
        wordLayer.addMarker({
          time: theTime,
          comment: theWord,
          overwrite: true
        });
      }
    }
  }
}

app.endUndoGroup();
