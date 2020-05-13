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
{ApolloServer} = require 'apollo-server-express'
{buildFederatedSchema} = require '@apollo/federation'

config = require './config'
helperConfig = require 'phil-helpers/lib/config'
helperConfig.set _.pick(config, config.SHARED_WITH_PHIL_HELPERS)
{Schema} = require 'phil-helpers'
{setup, childSetup} = require './services/setup'
directives = require './graphql/directives'

schema = Schema.getSchema({directives, dirName: __dirname})

Promise.config {warnings: false}

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
  {elasticsearch} = require 'phil-helpers'
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
          range:
            importVersion:
              lt: config.CURRENT_IMPORT_VERSION
  }
  .then (c) ->
    res.send JSON.stringify c

# pull in all eins / xml urls that filed for a given year
app.get '/loadAllForYear', (req, res) ->
  {loadAllForYear} = require './services/irs_990_importer/load_all_for_year'
  loadAllForYear req.query.year
  res.send "syncing #{req.query.year or 'sample_index'}"

app.get '/processUnprocessedOrgs', (req, res) ->
  {processUnprocessedOrgs} = require './services/irs_990_importer'
  processUnprocessedOrgs()
  res.send 'processing orgs'

app.get '/processUnprocessedFunds', (req, res) ->
  {processUnprocessedFunds} = require './services/irs_990_importer'
  processUnprocessedFunds()
  res.send 'processing funds'

app.get '/lastYearContributions', (req, res) ->
  {setLastYearContributions} = require './services/irs_990_importer'
  setLastYearContributions()
  res.send 'syncing'

app.get '/parseGrantMakingWebsites', (req, res) ->
  {parseGrantMakingWebsites} = require './services/irs_990_importer/parse_websites'
  parseGrantMakingWebsites()
  res.send 'syncing'

app.get '/setNtee', (req, res) ->
  {setNtee} = require './services/irs_990_importer/set_ntee'
  setNtee()
  res.send 'syncing'

graphqlServer = new ApolloServer {schema: buildFederatedSchema schema}
graphqlServer.applyMiddleware {app, path: '/graphql'}

server = http.createServer app

module.exports = {
  server
  setup
  childSetup
}
