# generated by Neptune Namespaces v2.x.x
# file: Art/Ery/.Server/index.coffee

module.exports = require './namespace'
module.exports
.includeInNamespace require './Server'
.addModules
  Main:                require './Main'               
  PromiseHttp:         require './PromiseHttp'        
  PromiseJsonWebToken: require './PromiseJsonWebToken'