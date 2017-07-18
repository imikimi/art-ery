{
  log, arrayWith
  defineModule, merge, isJsonType, isString, isPlainObject, isArray
  inspect
  inspectedObjectLiteral
  toInspectedObjects
  formattedInspect
  Promise
  ErrorWithInfo
  object
  isFunction
  objectWithDefinedValues
  objectWithout
  array
  isPromise
  compactFlatten
  present
} = require 'art-standard-lib'
ArtEry = require './namespace'
ArtEryBaseObject = require './ArtEryBaseObject'
{isClientFailure, success, missing, serverFailure, clientFailure, clientFailureNotAuthorized} = require 'art-communication-status'
{config} = require './Config'

###
TODO: merge reponse and request into one object

TODO: Work towards the concept of "oldData" - sometimes we need to know
 the oldData when updating. Specifically, ArtEryPusher needs to know the oldData
 to notify clients if a record is removed from one query and added to another.
 Without oldData, there is no way of knowing what old query it was removed from.
 In this case, either a) the client needs to send the oldData to the server of b)
 we need to fetch the oldData before overwriting it - OR we need to us returnValues: "allOld".

 Too bad there isn't a way to return BOTH the old and new fields with DynamoDb.

 Not sure if ArtEry needs any special code for "oldData." It'll probably be a convention
 that ArtEryAws and ArtEryPusher conform to. It's just a props from ArtEry's POV.
###

defineModule module, class RequestResponseBase extends ArtEryBaseObject

  constructor: (options) ->
    super
    {@filterLog} = options

  @property "filterLog"

  addFilterLog: (filter) -> @_filterLog = arrayWith @_filterLog, "#{filter}"

  @getter
    location:           -> @pipeline.location
    requestType:        -> @type
    pipelineName:       -> @pipeline.getName()
    requestDataWithKey: -> merge @requestData, @keyObject
    keyObject:          -> @request.pipeline.toKeyObject @key
    rootRequest:        -> @parentRequest?.rootRequest || @request

    inspectedObjects: ->
      "#{@class.namespacePath}":
        toInspectedObjects objectWithDefinedValues objectWithout @propsForClone, "context"

  # Pass-throughs - to remove once we merge Request and Response
  @getter
    requestProps:       -> @request.requestProps
    requestData:        -> @request.requestData
    isRootRequest:      -> @request.isRootRequest
    key:                -> @request.key || @responseData?.id
    pipeline:           -> @request.pipeline
    parentRequest:      -> @request.parentRequest
    type:               -> @request.type
    originatedOnServer: -> @request.originatedOnServer
    context:            -> @request.context
    requestString: ->
      str = "#{@pipelineName}.#{@type}"
      str += "[#{formattedInspect @key}]" if @key
      str

    requestPathArray: (into) ->
      localInto = into || []
      {parentRequest} = @
      if parentRequest
        parentRequest.getRequestPathArray localInto

      localInto.push @
      localInto

    requestPath: ->
      "<#{(r.toStringCore() for r in @requestPathArray).join ' >> '}>"

  toStringCore: ->
    "ArtEry.#{if @isResponse then 'Response' else 'Request'} #{@pipelineName}.#{@type}#{if @key then " key: #{@key}" else ''}"

  toString: ->
    "<#{@toStringCore()}>"

  ########################
  # Context Props
  ########################
  @getter
    requestCache:      -> @context.requestCache ||= {}
    subrequestCount:   -> @context.subrequestCount ||= 0

  @setter
    responseProps: -> throw new Error "cannot set responseProps"

  incrementSubrequestCount: -> @context.subrequestCount = (@context.subrequestCount | 0) + 1

  ########################
  # Subrequest
  ########################
  ###
  TODO:
    I think I may have a way clean up the subrequest API and do
    what is easy in Ruby: method-missing.

    Here's the new API:
      # request on the same pipeline
      request.pipeline.requestType requestOptions

      # request on another pipeline
      request.pipelines.otherPipelineName.requestType requestOptions

    Here's how:
      .pipeline and .pipelines are getters
      And the return proxy objects, generated and cached on the fly.

    Alt API idea:
      # same pipeline
      request.subrequest.requestType

      # other pipelines
      request.crossSubrequest.user.requestType

      I kinda like this more because it makes it clear we are talking
      sub-requests. This is just a ALIASes to the API above.
  ###
  createSubRequest: (pipelineName, type, requestOptions) ->
    throw new Error "requestOptions must be an object" if requestOptions && !isPlainObject requestOptions
    pipeline = ArtEry.pipelines[pipelineName]
    throw new Error "Pipeline not registered: #{formattedInspect pipelineName}" unless pipeline

    new ArtEry.Request merge {originatedOnServer: true}, requestOptions, {
      type
      pipeline
      @session
      parentRequest: @request
      @context
    }

  subrequest: (pipelineName, type, requestOptions) ->
    requestOptions = key: requestOptions if isString requestOptions
    pipelineName = pipelineName.pipelineName || pipelineName
    subrequest = @createSubRequest pipelineName, type, requestOptions

    @incrementSubrequestCount()
    promise = subrequest.pipeline._processRequest subrequest
    .then (response) => response.toPromise requestOptions

    # update returns the same data a 'get' would - cache it in case we need it
    # USE CASE: I just noticed Oz doing this in triggers on message creation:
    #   updating post
    #   reading post to update postParticipant
    # This doesn't help if the 'get' fires before the 'update', but it does help
    # if we are lucky and it happens the other way.
    if type == "update" && !requestOptions?.props?.returnValues && isString subrequest.key
      @_getPipelineTypeCache(pipelineName, type)[subrequest.key] = promise

    promise

  _getPipelineTypeCache: (pipelineName, type) ->
    (@requestCache[pipelineName] ||= {})[type] ||= {}

  cachedSubrequest: (pipelineName, type, key) ->
    throw new Error "key must be a string (#{formattedInspect {key}})" unless isString key
    @_getPipelineTypeCache(pipelineName, type)[key] ||= @subrequest pipelineName, type, {key}

  setGetCache: ->
    if @status == success && present(@key) && @responseData?
      @_getPipelineTypeCache(@pipelineName, "get")[@key] = Promise.then => @responseData

  cachedGet: cachedGet = (pipelineName, key) -> @cachedSubrequest pipelineName, "get", key
  cachedPipelineGet: cachedGet # depricated(?) alias

  # like cachedGet, excepts it success with null if it doesn't exist or if key doesn't exist
  cachedGetIfExists: (pipelineName, key) ->
    return Promise.resolve null unless key?
    @cachedGet pipelineName, key
    .catch (error) ->
      if error.info.response.status == missing
        Promise.resolve null
      else throw error


  ##############################
  # requirement helpers
  ##############################
  ###
  IN:
    test: booleanish
    message: string (optional)
  OUT:
    Success: promise.then (request) ->
    Failure: promise.catch (error) ->
      error.info.response # failing response
      error.info.response.data.message.match message # if message res provided

  Success if test is true
  ###
  require: (test, message) ->
    if test
      Promise.resolve @
    else
      message = message() if isFunction message
      @clientFailure data: message: message || "requirement not met"
      .then (response) -> response.toPromise()

  # returns rejecting promise if test is true
  # see @require
  rejectIf: (test, message) -> @require !test, message

  ###
  Success if @originatedOnServer is true
  OUT: see require
  ###
  requireServerOrigin: (message) ->
    @requireServerOriginOr true, message

  ###
  Success if either testResult or @originatedOnServer are true.
  OUT: see require
  ###
  requireServerOriginOr: (testResult, message) ->
    @require testResult || @originatedOnServer, ->
      message = "to #{message}" unless message.match /\s*to\s/
      "originatedOnServer required #{message || ''}"

  ###
  Success if either NOT testResult or @originatedOnServer are true.
  OUT: see require

  EXAMPLE: request.requireServerOriginIf createOk, "to use createOk"
  ###
  requireServerOriginIf: (testResult, message) -> @requireServerOriginOr !testResult, message

  ##################################
  # GENERATE NEW RESPONSES/REQUESTS
  ##################################

  # Clones this instance with optional overriding constructorOptions
  with: (constructorOptions) ->
    Promise.resolve(constructorOptions).then (constructorOptions) =>
      @_with constructorOptions

  # Private; expects 'o' to be a plainObject (not a promise -> plainObject)
  _with: (o) -> new @class merge @propsForClone, o

  ###
  IN: data can be a plainObject or a promise returning a plainObject
  OUT: promise.then (new request or response instance) ->

  withData:           new instance has @data replaced by `data`
  withMergedData:     new instance has @data merged with `data`
  withSession:        new instance has @session replaced by `session`
  withMergedSession:  new instance has @session merged with `session`
  ###
  withData:           (data)    -> Promise.resolve(data).then    (data)    => @_with {data}
  withMergedData:     (data)    -> Promise.resolve(data).then    (data)    => @_with data: merge @data, data
  withSession:        (session) -> Promise.resolve(session).then (session) => @_with {session}
  withMergedSession:  (session) -> Promise.resolve(session).then (session) => @_with session: merge @session, session

  respondWithSession:        (session) -> @success {session}
  respondWithMergedSession:  (session) -> @success session: merge @session, session

  ###
  IN:
    singleRecordTransform: (record, requestOrResponse) ->
      IN:
        record: a plain object
        requestOrResponse: this
      OUT: See EFFECT below
        (can return a Promise in all situations)

  EFFECT:
    if isPlainObject @data
      called once: singleRecordTransform @data
      if singleRecordTransform returns:
        null:         >> return status: missing
        plainObject:  >> return @withData data
        response:     >> return response

      See singleRecordTransform.OUT above for results

    if isArray @data
      Basically:
        @withData array record in @data with singleRecordTransform record

      But, each value returned from singleRecordTransform:
        null:                              omitted from array results
        response.status is clientFailure*: omitted from array results
        plainObject:                       returned in array results
        if any error:
            exception thrown
            rejected promise
            response.status is not success and not clientFailure
          then a failing response is returned

  ###
  withTransformedRecords: (singleRecordTransform) ->
    if isPlainObject @data then @next singleRecordTransform @data, @
    else if isArray @data
      firstFailure = null
      transformedRecords = array @data, (record) =>
        Promise.then => singleRecordTransform record, @
        .catch (error) =>
          if response error?.info?.response
            response
          else
            throw error
        .then (out) ->
          if out?.status && out instanceof RequestResponseBase
            if isClientFailure out.status
              out._clearErrorStack?()
              null
            else
              firstFailure ||= out
          else
            out

      Promise.all transformedRecords
      .then (records) =>
        firstFailure || @withData compactFlatten records

    else Promise.resolve @

  ###
  next is used right after a filter or a handler.
  It's job is to convert the results into a request or response object.

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
      else
        log.error invalidXYZ: data
        throw new Error "invalid response data passed to RequestResponseBaseNext"
        # TODO: should return an inspected version of Data IFF the server is in debug-mode

    # send response-errors back through the 'resolved' promise path
    # We allow them to be thrown in order to skip parts of code, but they should be returned normally
    , (error) =>
      if error.info?.response?.isResponse
        error.info.response
      else throw error

  success:                    (responseProps) -> @toResponse success, responseProps
  missing:                    (responseProps) -> @toResponse missing, responseProps
  clientFailure:              (responseProps) -> @toResponse clientFailure, responseProps
  clientFailureNotAuthorized: (responseProps) -> @toResponse clientFailureNotAuthorized, responseProps
  failure:                    (responseProps) -> @toResponse failure, responseProps
  # NOTE: there is no serverFailure method because you should always use just 'failure'.
  # This is because you may be running on the client or the server. If running on the client, it isn't a serverFailure.
  # If status == "failure", the ArtEry HTTP server will convert that status to serverFailure automatically.

  ##########################
  # PRIVATE
  ##########################
  ###
  IN:
    status: legal CommunicationStatus
    responseProps: (optionally Promise returning:)
      PlainObject:          directly passed into the Response constructor
      String:               becomes data: message: string
      RequestResponseBase:  returned directly
      else:                 considered internal error, but it will create a valid, failing Response object
  OUT:
    promise.then (response) ->
    .catch -> # should never happen
  ###
  toResponse: (status, responseProps) ->
    throw new Error "missing status" unless isString status

    # status = responseProps.status if isString responseProps?.status

    # if status != success && config.verbose
    #   log.error RequestResponseBase_toResponse:
    #     arguments: {status, responseProps}
    #     config: verbose: true
    #     request: {
    #       @requestPath
    #       @requestProps
    #       @session
    #     }
    #     error: Promise.reject new Error

    Promise.resolve responseProps
    .then (responseProps = {}) =>
      switch
        when responseProps instanceof RequestResponseBase
          log.warn "toResponse is instanceof RequestResponseBase - is this EVER used???"
          # if used, shouldn't this still transform Request objects into Response objects?
          responseProps

        when isPlainObject responseProps
          new ArtEry.Response merge @propsForResponse, responseProps, {status, @request}

        when isString responseProps
          @toResponse status, data: message: responseProps

        # unsupported responseProps type is an internal failure
        else
          @toResponse failure, @_toErrorResponseProps responseProps

  _toErrorResponseProps: (error) ->
    log @, {responseProps},
      data: message: if responseProps instanceof Error
          "Internal Error: ArtEry.RequestResponseBase#toResponse received Error instance: #{formattedInspect responseProps}"
        else
          "Internal Error: ArtEry.RequestResponseBase#toResponse received unsupported type"
