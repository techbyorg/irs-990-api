_ = require 'lodash'
assertNoneMissing = require 'assert-none-missing'

env = process.env

config =
  CURRENT_IMPORT_VERSION: 0 # increment any time you want to repull all data
  PORT: env.BACKEND_PORT or 3000
  ENV: env.DEBUG_ENV or env.NODE_ENV
  MAX_CPU: env.BACK_ROADS_MAX_CPU or 1
  REDIS:
    PREFIX: 'irs_990_api'
    PUB_SUB_PREFIX: 'irs_990_api_pub_sub'
    PORT: 6379
    CACHE_HOST: env.REDIS_CACHE_HOST or 'localhost'
    PUB_SUB_HOST: env.REDIS_PUB_SUB_HOST or 'localhost'
  SCYLLA:
    KEYSPACE: 'irs_990_api'
    PORT: 9042
    CONTACT_POINTS: (env.SCYLLA_CONTACT_POINTS or 'localhost').split(',')
  ELASTICSEARCH:
    PORT: 9200
    HOST: env.ELASTICSEARCH_HOST or 'localhost'
  ENVS:
    DEV: 'development'
    PROD: 'production'
    TEST: 'test'
  SHARED_WITH_PHIL_HELPERS: ['REDIS', 'SCYLLA', 'ELASTICSEARCH', 'ENVS', 'ENV']

assertNoneMissing config

module.exports = config
