Redis = require 'ioredis'
_ = require 'lodash'

config = require '../config'

client = new Redis {
  port: config.REDIS.PORT
  host: config.REDIS.CACHE_HOST
}

events = ['connect', 'ready', 'error', 'close', 'reconnecting', 'end']
_.map events, (event) ->
  client.on event, ->
    console.log config.REDIS.CACHE_HOST
    console.log "redislog #{event}"

module.exports = client
