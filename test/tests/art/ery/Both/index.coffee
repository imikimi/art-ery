# generated by Neptune Namespaces v1.x.x
# file: tests/Art/Ery/Both/index.coffee

module.exports = require './namespace'
.addModules
  AuthPipeline:   require './AuthPipeline'  
  Config:         require './Config'        
  FilterBase:     require './FilterBase'    
  Request:        require './Request'       
  Response:       require './response'      
  Session:        require './Session'       
  SimplePipeline: require './SimplePipeline'
require './Filters'
require './Flux'
require './Pipeline'