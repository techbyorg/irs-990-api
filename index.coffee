fs = require 'fs'
_ = require 'lodash'
log = require 'loga'
cors = require 'cors'
express = require 'express'
Promise = require 'bluebird'
bodyParser = require 'body-parser'
cluster = require 'cluster'
http = require 'http'
# socketIORedis = require 'socket.io-redis'
Redis = require 'ioredis'
router = require 'exoid-router'
{graphql} = require 'graphql'

config = require './config'
cknex = require './services/cknex'
ScyllaSetupService = require './services/scylla_setup'
ElasticsearchSetupService = require './services/elasticsearch_setup'
JobRunnerService = require './services/job_runner'
Irs990Service = require './services/irs_990'
schema = require './graphql/schema'

Promise.config {warnings: false}

setup = ->
  graphqlFolders = _.filter fs.readdirSync('./graphql'), (file) ->
    file.indexOf('.') is -1
  scyllaTables = _.flatten _.map graphqlFolders, (folder) ->
    model = require("./graphql/#{folder}/model")
    model?.getScyllaTables?() or []
  elasticSearchIndices = _.flatten _.map graphqlFolders, (folder) ->
    model = require("./graphql/#{folder}/model")
    model?.getElasticSearchIndices?() or []

  shouldRunSetup = true or config.ENV is config.ENVS.PRODUCTION or
                    config.SCYLLA.CONTACT_POINTS[0] is 'localhost'

  await Promise.all _.filter [
    if shouldRunSetup
      ScyllaSetupService.setup scyllaTables
      .then -> console.log 'scylla setup'
    if shouldRunSetup
      ElasticsearchSetupService.setup elasticSearchIndices
      .then -> console.log 'elasticsearch setup'
  ]
  .catch (err) ->
    console.log 'setup', err

  console.log 'scylla & elasticsearch setup'
  cknex.enableErrors()
  JobRunnerService.listen() # TODO: child instance too
  null # don't block

childSetup = ->
  JobRunnerService.listen()
  cknex.enableErrors()
  return Promise.resolve null # don't block

app = express()

app.set 'x-powered-by', false

app.use cors()

app.use bodyParser.json({limit: '1mb'})
# Avoid CORS preflight
app.use bodyParser.json({type: 'text/plain', limit: '1mb'})
app.use bodyParser.urlencoded {extended: true} # Kiip uses

app.get '/', (req, res) -> res.status(200).send 'ok'

app.get '/tableCount', (req, res) ->
  console.log 'count'
  elasticsearch = require './services/elasticsearch'
  elasticsearch.count {
    index: req.query.tableName
  }
  .then (c) ->
    res.send JSON.stringify c

app.get '/unprocessedCount', (req, res) ->
  IrsOrg990 = require './models/irs_fund_990'
  IrsOrg990.search {
    trackTotalHits: true
    limit: 1 # 16 cpus, 16 chunks
    query:
      bool:
        must:
          term:
            isProcessed: false
  }
  .then (c) ->
    res.send JSON.stringify c

# pull in all eins / xml urls that filed for a given year
app.get '/syncYear', (req, res) ->
  Irs990Service.syncYear req.query.year
  res.send "syncing #{req.query.year or 'sample_index'}"

app.get '/processUnprocessedOrgs', (req, res) ->
  Irs990Service.processUnprocessedOrgs()
  res.send 'processing orgs'

app.get '/processUnprocessedFunds', (req, res) ->
  Irs990Service.processUnprocessedFunds()
  res.send 'processing funds'

app.get '/lastYearContributions', (req, res) ->
  Irs990Service.setLastYearContributions()
  res.send 'syncing'

app.get '/parseGrantMakingWebsites', (req, res) ->
  Irs990Service.parseGrantMakingWebsites()
  res.send 'syncing'

app.get '/syncNtee', (req, res) ->
  Irs990Service.syncNtee()
  res.send 'syncing'

app.post '/graphql', (req, res) ->
  rootValue = undefined
  context = req
  graphql schema, req.body.graphql, rootValue, context, req.body.variables
  .then ({data, errors}) ->
    if errors
      res.send {errors}
    else
      res.send {data}

server = http.createServer app

module.exports = {
  server
  setup
  childSetup
}
