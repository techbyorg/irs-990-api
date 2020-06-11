fs = require 'fs'
path = require 'path'
_ = require 'lodash'
Promise = require 'bluebird'
{cknex, ElasticsearchSetup, JobRunner, ScyllaSetup} = require 'backend-shared'

config = require '../config'
{RUNNERS} = require './job'

setup = ->
  cknex.setDefaultKeyspace 'irs_990_api'
  graphqlFolders = _.filter fs.readdirSync('./graphql'), (file) ->
    file.indexOf('.') is -1
  scyllaTables = _.flatten _.map graphqlFolders, (folder) ->
    model = require("../graphql/#{folder}/model")
    model?.getScyllaTables?() or []
  elasticSearchIndices = _.flatten _.map graphqlFolders, (folder) ->
    model = require("../graphql/#{folder}/model")
    model?.getElasticSearchIndices?() or []

  shouldRunSetup = true or config.get().ENV is config.get().ENVS.PRODUCTION or
                    config.get().SCYLLA.CONTACT_POINTS[0] is 'localhost'

  await Promise.all _.filter [
    if shouldRunSetup
      ScyllaSetup.setup scyllaTables
      .then -> console.log 'scylla setup'
    if shouldRunSetup
      ElasticsearchSetup.setup elasticSearchIndices
      .then -> console.log 'elasticsearch setup'
  ]
  .catch (err) ->
    console.log 'setup', err

  console.log 'scylla & elasticsearch setup'
  cknex.enableErrors()
  JobRunner.listen RUNNERS
  null # don't block

childSetup = ->
  cknex.setDefaultKeyspace 'irs_990_api'
  JobRunner.listen RUNNERS
  cknex.enableErrors()
  return Promise.resolve null # don't block

module.exports = {
  setup
  childSetup
}
