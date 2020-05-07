Queue = require 'bull'
Redis = require 'ioredis'
_ = require 'lodash'

config = require '../config'

module.exports = {
  DEFAULT:
    new Queue 'MONOCLE_DEFAULT', {
      redis: {
        port: config.REDIS.PORT
        host: config.REDIS.CACHE_HOST
      }
      limiter: # 10 calls per second FIXME rm
        max: 7
        duration: 1000
  }
}
