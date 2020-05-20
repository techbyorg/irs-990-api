router = require 'exoid-router'
{Format} = require 'phil-helpers'

{defaultFieldResolver} = require 'graphql'
{SchemaDirectiveVisitor} = require 'graphql-tools'

module.exports = {
  fixAllCaps: class FixAllCaps extends SchemaDirectiveVisitor
    visitFieldDefinition: (field) ->
      {resolve = defaultFieldResolver} = field
      field.resolve = (...args) ->
        str = resolve.apply this, args
        Format.fixAllCaps str
      return # req'd bc of coffeescript
}
