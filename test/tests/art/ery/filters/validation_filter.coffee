{log, Validator} = require 'art-foundation'
{missing, Filters} = require 'art-ery'
SimplePipeline = require '../simple_pipeline'

{ValidationFilter} = Filters

suite "Art.Ery.Pipeline.Filters.ValidationFilter", ->
  test "preprocess", ->
    simplePipeline = new SimplePipeline()
    .addFilter new ValidationFilter
      foo: preprocess: (o) -> "#{o}#{o}"

    simplePipeline.create foo: 123
    .then (response) ->
      assert.eq response.foo, "123123"

  test "required field - missing", ->
    simplePipeline = new SimplePipeline()
    .addFilter new ValidationFilter
      foo: required: true

    simplePipeline.create bar: 123
    .then (data) ->
      throw "should not succeed"
    .catch (response) ->
      assert.eq response.error,
        invalidFields: []
        missingFields: ["foo"]

  test "required field - present", ->
    simplePipeline = new SimplePipeline()
    .addFilter new ValidationFilter
      foo: required: true

    simplePipeline.create foo: 123
    .then (data) ->
      assert.eq data.foo, 123

  test "validate - invalid", ->
    simplePipeline = new SimplePipeline()
    .addFilter new ValidationFilter
      foo: Validator.fieldTypes.trimmedString

    simplePipeline.create foo: 123
    .then (response) ->
      throw "should not succeed"
    .catch (response) ->
      assert.eq response.error,
        invalidFields: ["foo"]
        missingFields: []

  test "validate - valid with preprocessing", ->
    simplePipeline = new SimplePipeline()
    .addFilter new ValidationFilter
      foo: Validator.fieldTypes.trimmedString

    simplePipeline.create foo: "  123  "
    .then (data) ->
      assert.eq data.foo, "123"
