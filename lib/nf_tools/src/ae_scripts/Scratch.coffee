$.evalFile File($.fileName).path + "/runtimeLibraries.jsx"

app.beginUndoGroup 'Run Scratch Script'

searchBase = app.project
allItems = []
i = 1
while i <= searchBase.items.length
  thisItem = searchBase.items[i]
  if thisItem.name[0] is " "
    allItems.push thisItem
  i++

for item in allItems
  item.name = item.name.substring(1)

app.endUndoGroup()
