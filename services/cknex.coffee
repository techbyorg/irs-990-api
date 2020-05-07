cassanknex = require 'cassanknex'
cassandra = require 'cassandra-driver'
Promise = require 'bluebird'
moment = require 'moment'
_ = require 'lodash'
# callerId = require 'caller-id'

config = require '../config'

distance = cassandra.types.distance

contactPoints = config.SCYLLA.CONTACT_POINTS

cassanknexInstance = cassanknex
  connection:
    contactPoints: contactPoints
  exec:
    prepare: true
  pooling:
    coreConnectionsPerHost:
      "#{distance.local}": 4
      "#{distance.remote}": 1

# queryCount = 0
# setInterval ->
#   if queryCount
#     console.log 'qps', queryCount
#   queryCount = 0

ready = new Promise (resolve, reject) ->
  cassanknexInstance.on 'ready', (err, res) ->
    console.log 'cassandra', err, res
    if err
      reject err
    else
      resolve res

errorsEnabled = false

cknex = (keyspace = 'monocle') ->
  instance = cassanknexInstance keyspace
  instance.run = (options = {}) -> # skinny arrow on purpose
    # cid = callerId.getData()
    self = this
    ready.then ->
      new Promise (resolve, reject) ->
        # console.log cid
        # console.log self._columnFamily, self._statements
        # console.log ''
        # console.log '----------'
        # console.log ''
        self.exec options, (err, result) ->
          if result and not _.isEmpty result.rows
            result.rows = _.map result.rows, (row) ->
              # https://github.com/datastax/nodejs-driver/pull/243
              # (.values, .forEach, .keys, .get getting added)
              plainRow = {}
              for key, value of row
                if row.hasOwnProperty key
                  plainRow[key] = value
              plainRow
          # queryCount += 1
          if err
            if errorsEnabled
              console.log 'scylla err', self._columnFamily, err, self._statements
            reject err
          else if options.returnPageState
            resolve result
          else if options.isSingle
            resolve result.rows?[0]
          else
            resolve result.rows
  instance

cknex.getClient = ->
  cassanknexInstance.getClient()

cknex.enableErrors = ->
  errorsEnabled = true

cknex.getTimeUuid = (time) ->
  if time
    unless time instanceof Date
      time = moment(time).toDate()
    cassandra.types.TimeUuid.fromDate time
  else
    cassandra.types.TimeUuid.now()

cknex.getUuid = ->
  cassandra.types.Uuid.random()

cknex.getTimeUuidFromString = (timeUuidStr) ->
  cassandra.types.TimeUuid.fromString(timeUuidStr)

cknex.getUuidFromString = (uuidStr) ->
  cassandra.types.Uuid.fromString(uuidStr)

cknex.getDateFromTimeUuid = (timeuuid) ->
  timeuuid = if typeof timeuuid is 'string' \
       then cknex.getTimeUuidFromString timeuuid \
       else timeuuid
  timeuuid.getDate()

cknex.getTime = (time) ->
  if time
    unless time instanceof Date
      time = moment(time).toDate()
    time
  else
    new Date()

# cknex.chunkForBatchByPartition = (rows, partitionKey) ->
#

# FIXME FIXME: chunk all by partition. batching with mult partitions is slow/bad
# change maxChunkSize to 5kb (recommended. 30kb is probably fine though)?
cknex.chunkForBatch = (rows) ->
  # batch accepts max 50kb
  chunks = []
  chunkSize = 0
  chunkIndex = 0
  maxChunkSize = 30 * 1024 # 30kb. for some reason need big buffer from 50kb max
  _.forEach rows, (row) ->
    prevChunkSize = chunkSize
    chunkSize += JSON.stringify(row).length
    if prevChunkSize and chunkSize > maxChunkSize
      chunkSize = 0
      chunkIndex += 1
      chunks[chunkIndex] = []
    else if chunkIndex is 0
      chunks[chunkIndex] ?= []
    chunks[chunkIndex].push row
  return chunks

# batching supposedly shouldn't be used much. 50kb limit and:
# https://docs.datastax.com/en/cql/3.1/cql/cql_using/useBatch.html
# but indiv queries take long and seem to use more cpu
cknex.batchRun = (queries) ->
  if _.isEmpty queries
    return Promise.resolve null
  # queryCount += queries.length
  ready.then ->
    new Promise (resolve, reject) ->
      cassanknexInstance()
      .batch {prepare: true, logged: false}, queries, (err, result) ->
        if err
          console.log 'batch scylla err', err
          reject err
        else
          resolve result

module.exports = cknex
