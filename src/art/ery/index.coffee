# generated by Neptune Namespaces v0.1.0
# file: art/ery/index.coffee

(module.exports = require './namespace')
.includeInNamespace(require './_ery')
.addModules
  Artery:         require './artery'
  ArteryRegistry: require './artery_registry'
  EryStatus:      require './ery_status'
  Request:        require './request'
  Response:       require './response'