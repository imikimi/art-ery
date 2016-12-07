{
  BaseObject, CommunicationStatus, log, arrayWith
  defineModule, merge, isJsonType, isString, isPlainObject, inspect
  inspectedObjectLiteral
  toInspectedObjects
  formattedInspect
} = require 'art-foundation'
ArtEry = require './namespace'
ArtEryBaseObject = require './ArtEryBaseObject'
{success, missing, failure, clientFailure} = CommunicationStatus

defineModule module, class RequestResponseBase extends ArtEryBaseObject

  constructor: (options) ->
    super
    {@filterLog} = options

  @property "filterLog"

  addFilterLog: (filter) -> @_filterLog = arrayWith @_filterLog, "#{filter}"

  @getter
    inspectedObjects: ->
      "#{@class.namespacePath}":
        toInspectedObjects @props

  ###
  IN: data can be a plainObject or a promise returning a plainObject
  OUT: promise.then (newRequestWithNewData) ->
  ###
  withData: (data) ->
    Promise.resolve(data).then (resolvedData) =>
      new @class merge @props, data: resolvedData

  ###
  IN: data can be a plainObject or a promise returning a plainObject
  OUT: promise.then (newRequestWithNewData) ->
  ###
  withMergedData: (data) ->
    Promise.resolve(data).then (resolvedData) =>
      new @class merge @props, data: merge @data, resolvedData

  ###
  IN:
    null/undefined OR
    JSON-compabile data-type OR
    Response/Request OR
    something else - which is invalid, but is handled.

    OR a Promise returing one of the above

  OUT:
    if a Request or Response object was passed in, that is immediatly returned.
    Otherwise, this returns a Response object as follows:


    if data is null/undefined, return @missing
    if data is a JSON-compatible data structure, return @success with that data
    else, return @failure

  ###
  next: (data) ->
    Promise.resolve data
    .then (data) =>
      return data if data instanceof RequestResponseBase
      if !data?               then @missing()
      else if isJsonType data then @success {data}
      else                         @failure data: message: "invalid response data passed to RequestResponseBase#next"
        # TODO: should return an inspected version of Data IFF the server is in debug-mode

  success:        (responseProps) -> @_toResponse success, responseProps
  missing:        (responseProps) -> @_toResponse missing, responseProps
  failure:        (responseProps) -> @_toResponse failure, responseProps
  clientFailure:  (responseProps) -> @_toResponse clientFailure, responseProps
  # NOTE: there is no serverFailure method because you should always use just 'failure'.
  # This is because you may be running on the client or the server. If running on the client, it isn't a serverFailure.
  # If status == "failure" in the server's response, the client will convert that status to serverFailure automatically.

  ###
  IN:
    responseProps: (optionally Promise returning:)
      an object which is directly passed into the Response constructor
      OR instanceof RequestResponseBase
      OR anything else:
        considered internal error, but it will create a valid, failing Response object
  OUT:
    promise.then (response) ->
    .catch -> # should never happen
  ###
  _toResponse: (status, responseProps) ->
    if isPlainObject(status)
      {status} = responseProps = status
      throw new Error "missing status" unless status
    Promise.resolve responseProps
    .catch (e) =>
      status = failure
      e
    .then (responseProps = {}) =>
      return responseProps if responseProps instanceof RequestResponseBase
      # log _toResponse: {status, responseProps}

      responseProps = data: message: responseProps if isString responseProps
      unless isPlainObject responseProps
        status = failure
        message = null
        responseProps = data: message: if responseProps instanceof Error
          log.error(
            message = "Internal Error: ArtEry.RequestResponseBase#_toResponse received Error instance: #{formattedInspect responseProps}"
            @
            responseProps
          )
          message
        else
          log.error "Internal Error: ArtEry.RequestResponseBase#_toResponse expecting responseProps or error", responseProps

      response = new ArtEry.Response merge {@request, status}, responseProps

      if status == success
        Promise.resolve response
      else
        Promise.reject response