router = require 'exoid-router'

{SchemaDirectiveVisitor} = require 'graphql-tools'

module.exports = {
  # AuthDirective: class AuthDirective extends SchemaDirectiveVisitor
  #   visitFieldDefinition: (field) ->
  #     resolve = field.resolve
  #     field.resolve = (result, args, context, info) ->
  #       unless context.user?
  #         router.throw status: 401, info: 'Unauthorized', ignoreLog: true
  #       resolve result, args, context, info
  #     return # req'd bc of
}
