{log, createWithPostCreate, merge} = require 'art-foundation'
{missing, Pipeline} = Neptune.Art.Ery

module.exports = suite: ->
  setup ->
    Neptune.Art.Ery.config.location = "both"


  teardown ->
    Neptune.Art.Ery.config.location = "client"

  test "filter logs", ->
    createWithPostCreate class MyPipeline extends Pipeline
      @handlers foo: (request) -> merge request.data, foo: 1, bar: 2

      @filter
        name: "MyBeforeFooFilter"
        before: foo: (request) -> request.withMergedData MyBeforeFooFilter: true

      @filter
        name: "MyAfterFooFilter"
        after: foo: (response) -> response.withMergedData MyAfterFooFilter: true

    p = new MyPipeline
    p.foo
      returnResponseObject: true
    .then (response) ->
      assert.eq ["MyBeforeFooFilter"], (a.toString() for a in response.beforeFilterLog)
      assert.eq "handler", response.handledBy
      assert.eq ["MyAfterFooFilter"], (a.toString() for a in response.afterFilterLog)
      assert.eq response.data,
        foo: 1
        bar: 2
        MyAfterFooFilter: true
        MyBeforeFooFilter: true