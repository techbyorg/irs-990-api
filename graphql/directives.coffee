router = require 'exoid-router'
{Format} = require 'phil-helpers'

{defaultFieldResolver} = require 'graphql'
{SchemaDirectiveVisitor} = require 'graphql-tools'

module.exports = {
  nameCase: class NameCase extends SchemaDirectiveVisitor
    visitFieldDefinition: (field) ->
      {resolve = defaultFieldResolver} = field
      field.resolve = (...args) ->
        str = resolve.apply this, args
        Format.nameCase str
      return # req'd bc of coffeescript

  sentenceCase: class SentenceCase extends SchemaDirectiveVisitor
    visitFieldDefinition: (field) ->
      {resolve = defaultFieldResolver} = field
      field.resolve = (...args) ->
        str = resolve.apply this, args
        Format.sentenceCase str
      return # req'd bc of coffeescript
}
