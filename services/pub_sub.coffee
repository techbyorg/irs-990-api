Promise = require 'bluebird'
uuid = require 'node-uuid'
_ = require 'lodash'
Redis = require 'ioredis'

config = require '../config'

class PubSubService
  constructor: ->
    @subscriptions = {}
    @redisPub = new Redis {
      port: config.REDIS.PORT
      host: config.REDIS.PUB_SUB_HOST
    }
    @redisSub = new Redis {
      port: config.REDIS.PORT
      host: config.REDIS.PUB_SUB_HOST
    }

    @redisSub.on 'message', (channelWithPrefix, message) =>
      channel = channelWithPrefix.replace "#{config.REDIS.PUB_SUB_PREFIX}:", ''
      message = try
        JSON.parse message
      catch err
        console.log 'redis json parse error', channelWithPrefix
        {}
      _.forEach @subscriptions[channel], ({fn}) -> fn message

  publish: (channels, message) =>
    if typeof channels is 'string'
      channels = [channels]

    _.forEach channels, (channel) =>
      channelWithPrefix = "#{config.REDIS.PUB_SUB_PREFIX}:#{channel}"
      @redisPub.publish channelWithPrefix, JSON.stringify message

  subscribe: (channel, fn) =>
    channelWithPrefix = "#{config.REDIS.PUB_SUB_PREFIX}:#{channel}"

    unless @subscriptions[channel]
      @redisSub.subscribe (channelWithPrefix)
      @subscriptions[channel] ?= {}

    id = uuid.v4()
    @subscriptions[channel][id] = {
      fn: fn
      unsubscribe: =>
        if @subscriptions[channel]
          delete @subscriptions[channel][id]
        count = _.keys(@subscriptions[channel]).length
        unless count
          @redisSub.unsubscribe channelWithPrefix
          delete @subscriptions[channel]
    }

module.exports = new PubSubService()
