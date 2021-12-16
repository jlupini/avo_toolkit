var activeComp;

$.evalFile(File($.fileName).path + "/runtimeLibraries.jsx");

app.beginUndoGroup('Run Scratch Script');

activeComp = NFProject.activeComp();

activeComp.addBrowserWindow(activeComp.selectedLayers());

app.endUndoGroup();
