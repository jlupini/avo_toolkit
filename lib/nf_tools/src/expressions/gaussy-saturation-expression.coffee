duration = thisLayer("Effects")("AV Gaussy")("Duration").value / 100
maxSaturation = thisLayer("Effects")("AV Gaussy")("Saturation").value

if time < thisLayer.inPoint
  0
else if thisLayer.inPoint <= time < thisLayer.inPoint + duration
  progress = time - thisLayer.inPoint
  progress / duration * maxSaturation
else if thisLayer.inPoint + duration <= time < thisLayer.outPoint - duration
  maxSaturation
else if thisLayer.outPoint - duration <= time < thisLayer.outPoint
  progress = thisLayer.outPoint - time
  progress / duration * maxSaturation
else
  0
