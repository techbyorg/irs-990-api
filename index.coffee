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
{SchemaDirectiveVisitor} = require 'graphql-tools'

config = require './config'
helperConfig = require 'phil-helpers/lib/config'
helperConfig.set _.pick(config, config.SHARED_WITH_PHIL_HELPERS)
{Schema} = require 'phil-helpers'
{setup, childSetup} = require './services/setup'

directives = require './graphql/directives'
typeDefs = fs.readFileSync './graphql/type.graphql', 'utf8'

schema = Schema.getSchema {directives, typeDefs, dirName: __dirname}

Promise.config {warnings: false}

app = express()
app.set 'x-powered-by', false
app.use cors()
app.use bodyParser.json({limit: '1mb'})
# Avoid CORS preflight
app.use bodyParser.json({type: 'text/plain', limit: '1mb'})
app.use bodyParser.urlencoded {extended: true} # Kiip uses

app.get '/', (req, res) -> res.status(200).send 'ok'

validTables = [
  'irs_orgs', 'irs_org_990s', 'irs_funds', 'irs_fund_990s',
  'irs_persons', 'irs_contributions'
]
app.get '/tableCount', (req, res) ->
  if validTables.indexOf(req.query.tableName) is -1
    res.send {error: 'invalid table name'}
  {elasticsearch} = require 'phil-helpers'
  elasticsearch.count {
    index: req.query.tableName
  }
  .then (c) ->
    res.send JSON.stringify c

app.get '/unprocessedCount', (req, res) ->
  IrsOrg990 = require './graphql/irs_org_990/model'
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

# settings that supposedly make ES bulk insert faster
# (refresh interval -1 and 0 replicas). but it doesn't seem to make it faster
app.get '/setES', (req, res) ->
  {elasticsearch} = require 'phil-helpers'

  if req.query.mode is 'bulk'
    replicas = 0
    # refreshInterval = -1
  else # default / reset
    replicas = 2
    # refreshInterval = null

  res.send await Promise.map validTables, (tableName) ->
    settings = await elasticsearch.indices.getSettings {
      index: tableName
    }
    previous = settings[tableName].settings.index
    diff =
      number_of_replicas: replicas
      # refresh_interval: refreshInterval
    await elasticsearch.indices.putSettings {
      index: tableName
      body: diff
    }
    JSON.stringify {previous, diff}
  , {concurrency: 1}

app.get '/setMaxWindow', (req, res) ->
  if validTables.indexOf(req.query.tableName) is -1
    res.send {error: 'invalid table name'}

  maxResultWindow = parseInt req.query.maxResultWindow
  if maxResultWindow < 10000 or maxResultWindow > 100000
    res.send {error: 'must be number between 10,000 and 100,000'}

  {elasticsearch} = require 'phil-helpers'

  res.send await elasticsearch.indices.putSettings {
    index: req.query.tableName
    body: {max_result_window: maxResultWindow}
  }

# 2500/s on 4 pods each w/ 4vcpu (1.7mm total) = ~11 min
# bottleneck is queries-in-flight limit for scylla & es
# (throttled by # of cpus / concurrencyPerCpu in jobs settings / queue rate limiter)
# realistically the queue rate limiter is probably the blocker (x per second)
# set to as high as you can without getting scylla complaints.
# 25/s seems to be the sweet spot with current scylla/es setup (1 each)
app.get '/setNtee', (req, res) ->
  {setNtee} = require './services/irs_990_importer/set_ntee'
  setNtee()
  res.send 'syncing'

# pull in all eins / xml urls that filed for a given year
# run for 2014, 2015, 2016, 2017, 2018, 2019, 2020
# 2015, 2016 done FIXME rm this line
# each takes ~3 min (1 cpu)
# bottleneck is elasticsearch writes (bulk goes through, but some error if server is overwhelmed).
app.get '/loadAllForYear', (req, res) ->
  {loadAllForYear} = require './services/irs_990_importer/load_all_for_year'
  loadAllForYear req.query.year
  res.send "syncing #{req.query.year or 'sample_index'}"

# go through every 990 we haven't processed, and get data for it from xml file/irsx
# ES seems to be main bottleneck. we bulk reqs, but they're still slow.
# 1/2 of time is spent on irsx, 1/2 on es upserts
# if we send too many bulk reqs at once, es will start to send back errors
# i think the issue is bulk upserts in ES are just slow in general.

# faster ES node seems to help a little, but not much...
# cheapest / best combo seems to be 4vcpu/8gb for ES, 8x 2vcpu/2gb for api.
# ^^ w/ 2 job concurrencyPerCpu, that's 32. 32 * 300 (chunk) = 9600 (limit)
#    seems to be sweet spot w/ ~150-250 orgs/s (2-3 hours total)
#    could probably go faster with more cpus (bottleneck at this point is irsx)
# might need to increase thread_pool.write.queue_size to 1000
app.get '/processUnprocessedOrgs', (req, res) ->
  {processUnprocessedOrgs} = require './services/irs_990_importer'
  processUnprocessedOrgs req.query
  res.send 'processing orgs'

app.get '/processEin', (req, res) ->
  {processEin} = require './services/irs_990_importer'
  processEin req.query.ein, {type: req.query.type}
  res.send 'processing org'

# chunkConcurrency=10
# chunkConcurrency = how many orgs of a chunk to process simultaneously...
# doesn't matter for orgs, but for funds it does (since there's an es fetch)
# sweet spot is 1600&chunkSize=50&chunkConcurrency=3 (slow)
app.get '/processUnprocessedFunds', (req, res) ->
  {processUnprocessedFunds} = require './services/irs_990_importer'
  processUnprocessedFunds req.query
  res.send 'processing funds'

app.get '/parseGrantMakingWebsites', (req, res) ->
  {parseGrantMakingWebsites} = require './services/irs_990_importer/parse_websites'
  parseGrantMakingWebsites()
  res.send 'syncing'

{typeDefs, resolvers, schemaDirectives} = schema
schema = buildFederatedSchema {typeDefs, resolvers}
# https://github.com/apollographql/apollo-feature-requests/issues/145
SchemaDirectiveVisitor.visitSchemaDirectives schema, schemaDirectives

graphqlServer = new ApolloServer {
  schema: schema
  introspection: true
  playground: true
}
graphqlServer.applyMiddleware {app, path: '/graphql'}

server = http.createServer app

module.exports = {
  server
  setup
  childSetup
}
