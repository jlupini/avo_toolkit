$.evalFile File($.fileName).path + "/runtimeLibraries.jsx"

app.beginUndoGroup 'Run Scratch Script'

# searchBase = app.project
# allItems = []
# i = 1
# while i <= searchBase.items.length
#   thisItem = searchBase.items[i]
#   if thisItem.name[0] is " "
#     allItems.push thisItem
#   i++
#
# for item in allItems
#   item.name = item.name.substring(1)

# start_folder = new Folder(new File($.fileName).parent.parent.fsName)
# unless app.project.file?
#   throw new Error "Can't find the location of the project file. This could be because the project is not saved."
# project_folder = new Folder(app.project.file.parent.fsName)
# bashFile = new File(start_folder.fsName + '/lib/stt/systemcall.sh')
# sttFolder = File(start_folder.fsName + '/lib/stt/')
# audioLayer = NFProject.allPartComps()[0].greenscreenLayer()
# audioFile = audioLayer.$.source.file
#
# cmdLineString = "sh '#{bashFile.fsName}' '#{sttFolder.fsName}' '#{audioFile.fsName}' '#{project_folder.fsName}'"
#
# termfile = new File(File($.fileName).parent.fsName + '/command.term')
# command = cmdLineString
# termfile.open 'w'
# termfile.writeln '<?xml version="1.0" encoding="UTF-8"?>\n' +
#                  '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"' +
#                  '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n' +
#                  '<plist version="1.0">\n' +
#                  '<dict>\n' +
#                  '<key>WindowSettings</key>\n' +
#                  '<array>\n' +
#                  ' <dict>\n' +
#                  '<key>CustomTitle</key>\n' +
#                  '<string>My first termfile</string>\n' +
#                  '<key>ExecutionString</key>\n' +
#                  '<string>' +
#                  command +
#                  '</string>\n' +
#                  '</dict>\n' +
#                  '</array>\n' +
#                  '</dict>\n' +
#                  '</plist>\n'
# termfile.close()
# shouldContinue = confirm "This involves running a terminal instance to perform speech to text
#                           and line up timecodes. It may take a while and you'll have to check
#                           the terminal window to follow the progress. Continue?", false, "Run Script?"
# termfile.execute() if shouldContinue

instructionFile = "transcript.csv"
throw new Error "Cannot read #{instructionFile}" unless NFTools.testProjectFile instructionFile
instructionString = NFTools.readProjectFile instructionFile
instructionArray = instructionString.splitCSV()

# Add the line and instruction markers to part comps
allParts = NFProject.allPartComps()
lineWrap = "...\n"
for part in allParts

  wordLayer = part.addSolid
    color: [0,1,0.2]
    name: "Words"
  wordLayer.moveBefore part.allLayers().getBottommostLayer()

  # instructionLayer = part.addSolid
  #   color: [0,0.8, 0.4]
  #   name: "Instructions"
  # instructionLayer.moveBefore lineLayer

  wordLayer.$.guideLayer = yes
  wordLayer.$.enabled = no

  markers = wordLayer.markers()

  maxWordsPerMarker = 3 #max number of words per marker before truncation
  minFrequency = 1 #how many seconds minimum between markers

  skipNext = no
  for word, i in instructionArray
    unless i is 0
      theTime = parseFloat(word[0])
      unless isNaN(theTime)
        theWord = word[1]

        if markers.numKeys > 0
          nearestMarkerIdx = markers.nearestKeyIndex theTime
          nearestMarkerTime = markers.keyTime nearestMarkerIdx
          if nearestMarkerTime is theTime or theTime - nearestMarkerTime < minFrequency
            theTime = nearestMarkerTime
            existingComment = markers.keyValue(nearestMarkerIdx).comment
            wordCount = existingComment.split(' ').length
            if wordCount is maxWordsPerMarker
              theWord = existingComment
              unless theWord.indexOf("...") >= 0
                theWord += "..."
            else if wordCount < maxWordsPerMarker
              theWord = "#{existingComment} #{theWord}"

        wordLayer.addMarker
          time: theTime
          comment: theWord
          overwrite: yes



app.endUndoGroup()
