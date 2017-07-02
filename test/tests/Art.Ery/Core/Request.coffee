{log, CommunicationStatus, formattedInspect, merge, deepMerge, createWithPostCreate} = require 'art-foundation'
{clientFailure} = CommunicationStatus
{Request, Pipeline, KeyFieldsMixin} = Neptune.Art.Ery

newRequest = (options) ->
  new Request merge
    type:   "get"
    pipeline: new Pipeline
    session: {}
    options

class MyCompoundKeyPipe extends KeyFieldsMixin Pipeline
  @keyFields "userId/postId"

newCompoundKeyRequest = (options) ->
  new Request merge
    type:   "get"
    pipeline: new MyCompoundKeyPipe
    session: {}
    options

module.exports = suite:
  props: ->
    test "new Request key and data set via props:", ->

      assert.selectedPropsEq
        # via getters
        key:    "123"
        data:   "abc"
        props:  props = key: "123", data: "abc"

        new Request
          type:   "get"
          props:
            key:    "123"
            data:   "abc"
          session:  {}
          pipeline: new Pipeline

    test "new Request props: myProp: 987", ->

      assert.selectedPropsEq
        # via getters
        key:    undefined
        data:   undefined
        props:  myProp: 987

        new Request
          type:     "get"
          props:    myProp: 987
          session:  {}
          pipeline: new Pipeline

    test "new Request key: and data: are merged into props:", ->

      assert.selectedPropsEq
        # via getters
        key:    "123"
        data:   "abc"
        props:  props = key: "123", data: "abc", customProp: "xyz"

        # direct reads
        _key:   undefined
        _data:  undefined
        _props: props

        new Request
          type:   "get"
          key:    "123"
          data:   "abc"
          props:  customProp: "xyz"
          session:  {}
          pipeline: new Pipeline

  validation:
    "valid new Request": ->
      test "type: 'get'", ->
        new Request
          type: "get"
          key: "123"
          pipeline: new Pipeline
          session: {}

      test "type: 'create'", ->
        new Request
          type: "create"
          pipeline: new Pipeline
          session: {}

      test "type: 'update'", ->
        new Request
          type: "update"
          key: "123"
          pipeline: new Pipeline
          session: {}

      test "type: 'delete'", ->
        new Request
          type: "delete"
          key: "123"
          pipeline: new Pipeline
          session: {}

      test "inspectedObjects new Request", ->
        request = new Request
          type:     "get"
          key:      "123"
          pipeline: new Pipeline
          session:  {}

        assert.selectedPropsEq
          type:             "get"
          props:            key: "123"
          session:          {}
          request.inspectedObjects["Neptune.Art.Ery.Request"]

    "invalid new Request": ->
      test "missing everything", ->
        assert.throws -> new Request

      test "missing session", ->
        assert.throws ->
          new Request
            type: "get"
            key: "123"
            pipeline: new Pipeline

      test "key: {}", ->
        assert.throws ->
          new Request
            session: {}
            type: "get"
            key: {}
            pipeline: new Pipeline

      test "props: key: {}", ->
        assert.throws ->
          new Request
            session: {}
            type: "get"
            props: key: {}
            pipeline: new Pipeline

  properties: ->
    test "getKey", ->
      request = new Request
        type: "get"
        pipeline: new Pipeline
        session: {}
        props: key: "123"
      assert.eq request.getKey(), "123"

    test "getRequestType alias for getType", ->
      request = new Request
        type: "get"
        pipeline: new Pipeline
        session: {}
      assert.eq request.getRequestType(), "get"
      assert.eq request.getType(), "get"

  withData: ->
    test "withData", ->
      request = new Request
        type: "create"
        pipeline: new Pipeline
        session: {}
        data: {}
      request.withData foo: "bar"
      .then (newRequest) ->
        assert.neq newRequest, request
        assert.eq newRequest.data, foo: "bar"

    test "withMergedData", ->
      request = new Request
        type: "create"
        pipeline: new Pipeline
        session: {}
        data: bing: "bong"
      request.withMergedData foo: "bar"
      .then (newRequest) ->
        assert.neq newRequest, request
        assert.eq newRequest.data, bing: "bong", foo: "bar"

  derivedRequestsPersistProps: ->
    test "originatedOnServer", ->
      request = new Request
        type: "get"
        key: "123"
        originatedOnServer: true
        pipeline: new Pipeline
        session: {}

      request.withData({}).then (derivedRequest) ->
        assert.selectedPropsEq
          originatedOnServer: true
          type:     "get"
          key:      "123"
          pipeline: request.pipeline
          derivedRequest

  remoteRequestProps: ->

    test "create", ->
      assert.eq
        method: "post"
        url:    "/api/pipeline"
        data:   data: myField: "myInitialValue"
        newRequest(type: "create", data: myField: "myInitialValue").remoteRequestProps

    test "get", ->
      assert.eq
        method: "get"
        url:    "/api/pipeline/myKey"
        data:   null
        newRequest(type: "get", key: "myKey").remoteRequestProps

    test "get with compound key", ->
      assert.eq
        method: "get"
        url:    "/api/pipeline"
        data:   data: userId: "abc", postId: "xyz"
        newRequest(type: "get", data: userId: "abc", postId: "xyz").remoteRequestProps

    test "delete", ->
      assert.eq
        method: "delete"
        url:    "/api/pipeline/myKey"
        data:   null
        newRequest(type: "delete", key: "myKey").remoteRequestProps

    test "update", ->
      assert.eq
        method: "put"
        url:    "/api/pipeline/myKey"
        data:   data: myField: "myNewValue"
        newRequest(type: "update", key: "myKey", data: myField: "myNewValue").remoteRequestProps

    test "update myAdd: 1", ->
      assert.eq
        method: "put"
        url:    "/api/pipeline/myKey"
        data:   props: myAdd: myCount: 1
        newRequest(type: "update", key: "myKey", props: myAdd: myCount: 1).remoteRequestProps

  context:
    basics: ->
      test "context doesn't get passed to remote", ->
        request = newRequest()
        request.context.foo = "bar"
        assert.eq
          method: "get"
          url:    "/api/pipeline"
          data:   null
          request.remoteRequestProps

    "is identical after": ->
      test "request cloning", ->
        request = newRequest()
        {context} = request
        request.withMergedData user: "alice"
        .then (request) ->
          assert.same context, request.context

      test "response generation", ->
        request = newRequest()
        {context} = request
        request.success()
        .then (response) ->
          assert.same context, response.context

      test "subrequests", ->
        createWithPostCreate class MyPipeline extends Pipeline
          ;

        request = newRequest()
        {context} = request
        subrequest = request.createSubRequest "myPipeline", "get"
        assert.same context, subrequest.context

  require: ->
    test "require failure returns rejected promise", ->
      request = newRequest()
      assert.rejects request.require false, "abracadabra"
      .then (rejectsWith) ->
        {status, data} = rejectsWith.info.response
        assert.eq status, clientFailure
        assert.ok data.message.match /abracadabra/

    test "require success returns request", ->
      request = newRequest()
      request.require true, "abracadabra"
      .then (resolvesWith) ->
        assert.eq request, resolvesWith

  compoundKeys: ->
    request = null
    setup ->
      request = newCompoundKeyRequest
        key: userId: "userAbc", postId: "postXyz"
        data: followerCount: 123

    test "key", -> assert.eq request.key, "userAbc/postXyz"
    test "keyObject", -> assert.eq request.keyObject, userId: "userAbc", postId: "postXyz"
    test "requestDataWithKey", -> assert.eq request.requestDataWithKey, userId: "userAbc", postId: "postXyz", followerCount: 123