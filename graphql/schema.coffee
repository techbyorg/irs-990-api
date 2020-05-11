fs = require 'fs'
path = require 'path'
_ = require 'lodash'
{makeExecutableSchema} = require 'graphql-tools'
{ GraphQLJSON, GraphQLJSONObject } = require 'graphql-type-json'
BigInt = require 'graphql-bigint'
{mergeTypes, mergeResolvers} = require 'merge-graphql-schemas';

{} = require './directives'

graphqlFolders = _.filter fs.readdirSync('./graphql'), (file) ->
  file.indexOf('.') is -1
typesArray = _.filter _.map graphqlFolders, (folder) ->
  try
    fs.readFileSync "./graphql/#{folder}/type.graphql", 'utf8'
  catch
    null
typesArray = typesArray.concat '''
  type Query

  directive @auth on FIELD_DEFINITION

  type Mutation

  scalar BigInt
  scalar Date
  scalar JSON
  scalar JSONObject
'''
typeDefs = mergeTypes typesArray, {all: true}

resolversArray = _.filter _.map graphqlFolders, (folder) ->
  try
    require "./#{folder}/resolvers"
  catch err
    if err.code isnt 'MODULE_NOT_FOUND'
      console.error 'error loading', folder, err
    null
resolversArray = resolversArray.concat {
  BigInt: BigInt
  JSON: GraphQLJSON
  JSONObject: GraphQLJSONObject
}
resolvers = mergeResolvers resolversArray

module.exports = makeExecutableSchema {
  typeDefs
  resolvers
  # schemaDirectives:
  #   auth: AuthDirective
}
