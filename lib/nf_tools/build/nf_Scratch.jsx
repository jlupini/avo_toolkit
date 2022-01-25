var allItems, i, item, j, len, searchBase, thisItem;

$.evalFile(File($.fileName).path + "/runtimeLibraries.jsx");

app.beginUndoGroup('Run Scratch Script');

searchBase = app.project;

allItems = [];

i = 1;

while (i <= searchBase.items.length) {
  thisItem = searchBase.items[i];
  if (thisItem.name[0] === " ") {
    allItems.push(thisItem);
  }
  i++;
}

for (j = 0, len = allItems.length; j < len; j++) {
  item = allItems[j];
  item.name = item.name.substring(1);
}

app.endUndoGroup();
