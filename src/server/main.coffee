### npm Modules ###

express = require('express')
app = express()
request = require('request')
http = require('http')
path = require('path')
bodyParser = require('body-parser')

pdfjsLib = require('pdfjs-dist')
pdfjsWorker = require('pdfjs-dist/build/pdf.worker.entry')
pdfjsLib.GlobalWorkerOptions.workerSrc = pdfjsWorker

fs = require('fs')
httpServer = http.Server(app)

# Import Local Classes and files
jlpdf = require "./jlpdf.js"

run = ->
  port = 3200
  hostname = 'localhost'
  httpServer.listen port

  app.use bodyParser.json()
  app.use bodyParser.urlencoded(
    limit: '50mb'
    extended: true)
  app.use express.static(path.join(__dirname, '../client'))

  app.get '/import', (req, res, next) ->
    path = req.headers['directory'] + '/placeholder.png'
    uri = 'http://via.placeholder.com/350x150'

    saveImage = (uri, filepath, callback) ->
      request.head uri, (err, res, body) ->
        request(uri).pipe(fs.createWriteStream(filepath)).on 'close', callback

    saveImage uri, path, ->
      res.status(200).send path

  app.get '/annotationData', (req, res, next) ->
    path = req.query.filepath

    viewport = 1
    annotations = 1
    textContent = 1

    round = (value, precision = 4) ->
      multiplier = 10 ** (precision or 0)
      Math.round(value * multiplier) / multiplier
    merge = (r1, r2) ->
      width = if r1.width > r2.width then r1.width else r2.width + r2.left - (r1.left)
      height = if r1.height > r2.height then r1.height else r2.height + r2.top - (r1.top)
      {
        left: Math.min(r1.left, r2.left)
        top: Math.min(r1.top, r2.top)
        width: width
        height: height
      }

    handleError = (reason) ->
      console.error 'Error processing PDF: ' + reason
      res.status(500).send()

    handleSuccess = ->
      console.log 'PDF Processing success'
      res.status(200).send jlpdf.processRawAnnotationData
        annotations: annotations
        viewport: viewport.viewBox
        textContent: textContent

    console.log "Processing PDF: #{path}"

    afterLoad = (doc) ->

      loadPage = (pageNum) ->
        doc.getPage(pageNum).then (page) ->
          viewport = page.getViewport(1.0)

          processAnnotations = (content) ->
            annotations = []
            for annotation, i in content
              unless annotation.subtype is "Link"
                annotations.push
                  borderStyle: annotation.borderStyle.style
                  color: jlpdf.trimColorArray(annotation.color)
                  rect: annotation.rect
                  subtype: annotation.subtype
                  annotationType: annotation.annotationType
                  colorName: jlpdf.nearestColorName(annotation.color)

          processTextContent = (content) ->

            textItems = []
            prevItem = {}
            mergeCount = 0
            content.items.forEach (item) ->
              tx = pdfjsLib.Util.transform(viewport.transform, item.transform)
              fontHeight = Math.sqrt((tx[2] * tx[2]) + (tx[3] * tx[3]))

              newItem =
                str: item.str
                # tx: tx
                fontHeight: fontHeight
                width: round(item.width)
                # height: round(item.height/fontHeight)
                height: round(item.height)
                left: round(tx[4])
                top: round(tx[5] - fontHeight)

              # Combine together items on the same lines to reduce JSON file size
              prevItem = textItems[textItems.length - 1] if textItems.length isnt 0
              # console.log "Ding:  #{Math.abs(prevItem.top - newItem.top) < prevItem.height}"
              if prevItem? and ( Math.abs(prevItem.top - newItem.top) < prevItem.height )
                mergedRect = merge prevItem, newItem
                # console.log "merged"
                mergeCount++
                combinedItem =
                  str: "#{prevItem.str} // #{newItem.str}"
                  width: round(mergedRect.width)
                  height: round(mergedRect.height)
                  left: round(mergedRect.left)
                  top: round(mergedRect.top)
                textItems[textItems.length - 1] = combinedItem
              else
                textItems.push newItem
              return
            # console.log "Merged #{mergeCount} objects"

            textContent = textItems

          page.getAnnotations().then processAnnotations
          page.getTextContent().then processTextContent

      # Loading of the first page will wait on metadata and subsequent loadings
      # will wait on the previous pages.
      numPages = doc.numPages
      lastPromise = doc.getMetadata().then (data) -> return null

      i = 1
      while i <= numPages
        lastPromise = lastPromise.then loadPage.bind(null, i)
        i++
      lastPromise

    loadingTask = pdfjsLib.getDocument(path)
    loadingTask.promise.then(afterLoad).then handleSuccess, handleError


module.exports =
  run: run
  close: ->
    httpServer.close()
