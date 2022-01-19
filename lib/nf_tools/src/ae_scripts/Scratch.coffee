$.evalFile File($.fileName).path + "/runtimeLibraries.jsx"

app.beginUndoGroup 'Run Scratch Script'

activeComp = NFProject.activeComp()
activeComp.addBrowserWindow activeComp.selectedLayers()
# activeComp = NFProject.activeComp()
# selectedLayer = activeComp.selectedLayers()
# if selectedLayer.count() is 1
#   selectedLayer = selectedLayer.get(0)
#   app.executeCommand 19
#
#   browserImage = NFProject.findItem "safari-browser-v01.ai"
#
#   webCompsFolder = NFProject.findItem "Website Comps"
#   unless webCompsFolder
#     assetsFolder = NFProject.findItem "Assets"
#     webCompsFolder = assetsFolder.items.addFolder "Website Comps"
#
#   matteCompItem = NFProject.findItemIn "Browser Matte", webCompsFolder
#   if matteCompItem?
#     matteComp = new NFComp matteCompItem
#   else
#     matteComp = new NFComp webCompsFolder.items.addComp("Browser Matte", 1920, 1080, 1, 600, 30)
#     matteSolid = new NFLayer matteComp.$.layers.addSolid([0.5,0.5,0.5], 'Matte Layer', 1920, 1080, 1)
#     newMask = matteSolid.mask().addProperty "Mask"
#     newMask.name = "Mask 1"
#     newMask.maskShape.expression = "createPath(points = [[0,132], [1920, 132], [1920, 1080], [0, 1080]], inTangents = [], outTangents = [], is_closed = true);"
#
#   webComp = new NFComp webCompsFolder.items.addComp("NF-WEBSITE - #{selectedLayer.getName()}", 1920, 1080, 1, 600, 30)
#
#   webComp.$.openInViewer()
#   app.executeCommand 20
#   footageLayer = new NFLayer webComp.$.layer(1)
#   footageLayer.$.collapseTransformation = true
#   footageLayer.$.startTime = 0
#
#   browserLayer = new NFLayer webComp.$.layers.add(browserImage)
#   browserLayer.transform("Scale").setValue [417.4, 417.4]
#   browserLayer.transform("Anchor Point").setValue [0, 0]
#   browserLayer.transform("Position").setValue [0, 0]
#   browserLayer.$.collapseTransformation = true
#   browserLayer.moveAfter footageLayer
#
#   matteLayer = webComp.insertComp
#     comp: matteComp
#     at: 0
#     time: 0
#   matteLayer.$.enabled = no
#
#   matteEffect = footageLayer.addEffect("ADBE Set Matte3")
#   matteEffect.property("Take Matte From Layer").setValue 1
#
#   textLayer = webComp.addTextLayer
#     text: "https://www.website.com/page/subpage/subpage/"
#     above: matteLayer
#     fontSize: 29
#     font: "Proxima Nova"
#   textLayer.transform("Position").setValue [353, 94]
#
#   activeComp.$.openInViewer()
#   webCompLayer = activeComp.insertComp
#     comp: webComp
#     above: selectedLayer
#     time: selectedLayer.$.inPoint
#   gaussyLayer = activeComp.addGaussy
#     layer: webCompLayer
#     time: selectedLayer.$.inPoint
#
#   webCompLayer.slideIn
#     fromEdge: NFComp.BOTTOM
#   webCompLayer.$.motionBlur = yes
#
#   webCompLayer.effect("Start Offset").property("Slider").setValue(1660)
#   shadowProp = webCompLayer.addEffect('ADBE Drop Shadow')
#   shadowProp.property('Opacity').setValue(51)
#   shadowProp.property('Direction').setValue(0)
#   shadowProp.property('Distance').setValue(10)
#   shadowProp.property('Softness').setValue(60)
#
#   selectedLayer.remove()
#   webCompLayer.$.label = 16
#
# else alert "wrong number of layers selected"

# partComp = NFProject.activeComp()
#
# str = '{"target":{"class":"NFPageComp","name":"26_pg02 NFPage","id":2679,"numLayers":6,"pageNumber":"02","pdfNumber":"26","shapes":[{"class":"NFHighlightLayer","name":"Highlighter 2","index":1,"isActiveNow":null,"inPoint":4.33767100433767,"outPoint":604.337671004338,"containingComp":{"class":"NFPageComp","name":"26_pg02 NFPage","id":2679,"numLayers":6,"pageNumber":"02","pdfNumber":"26"}},{"class":"NFHighlightLayer","name":"Highlighter","index":2,"isActiveNow":null,"inPoint":0,"outPoint":600,"containingComp":{"class":"NFPageComp","name":"26_pg02 NFPage","id":2679,"numLayers":6,"pageNumber":"02","pdfNumber":"26"}}]},"command":"switch-to-page"}'
# partComp.runLayoutCommand JSON.parse(str)

app.endUndoGroup()
