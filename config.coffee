_ = require 'lodash'
assertNoneMissing = require 'assert-none-missing'

env = process.env

config =
  CURRENT_IMPORT_VERSION: 13 # increment any time you want to repull all data
  VALID_RETURN_VERSIONS: [
    # https://github.com/breezyhq/990-xml-reader/blob/master/irs_reader/settings.py#L36
    '2013v3.0', '2013v3.1', '2013v4.0', '2014v5.0', '2014v6.0',
    '2015v2.0', '2015v2.1', '2015v3.0', '2016v3.0', '2016v3.1',
    '2017v2.0', '2017v2.1', '2017v2.2', '2017v2.3', '2018v3.0',
    '2018v3.1'
  ]
  PORT: env.BACKEND_PORT or 3000
  ENV: env.DEBUG_ENV or env.NODE_ENV
  MAX_CPU: env.IRS_990_API_MAX_CPU or 1
  IRSX_CACHE_DIRECTORY: '/tmp'
  IRSX_XML_HTTP_BASE: env.IRSX_XML_HTTP_BASE or 'https://s3.amazonaws.com/irs-form-990'
  NTEE_CSV: 'https://nccs-data.urban.org/data/bmf/2019/bmf.bm1908.csv'
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
