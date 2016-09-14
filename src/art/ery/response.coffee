Foundation = require 'art-foundation'
Request = require './Request'
{BaseObject, arrayWith, inspect, isPlainObject, log, CommunicationStatus, Validator, merge, isJsonType, formattedInspect} = Foundation
{success, missing, failure} = CommunicationStatus

responseValidator = new Validator
  request:  required: instanceof: Request
  status:   required: "communicationStatus"
  data:     validate: (a) -> a == undefined || isJsonType a
  session:  "object"

module.exports = class Response extends require './RequestResponseBase'
  constructor: (options) ->
    super
    responseValidator.preCreateSync options, context: "Response options"
    {@request, @status, @data, @session, @error} = options
    # log newResponse: @inspectedObjects

  isResponse: true
  toString: -> "ArtEry.Response(#{@type}: #{@status}): #{@message}"

  @property "request status data session error"
  @getter
    type:             -> @request.type
    serverSideOrigin: -> @request.serverSideOrigin
    beforeFilterLog:  -> @request.filterLog
    afterFilterLog:   -> @filterLog
    message:          -> @data?.message
    isSuccessful:     -> @_status == success
    notSuccessful:    -> @_status != success
    props: ->
      request:    @request
      status:     @status
      data:       @data
      session:    @session
      filterLog:  @filterLog
