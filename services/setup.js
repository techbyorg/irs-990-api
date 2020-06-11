import fs from 'fs'
import _ from 'lodash'
import Promise from 'bluebird'
import { 
  cknex, elasticsearch, ElasticsearchSetup, JobRunner, ScyllaSetup, Cache, PubSub
} from 'backend-shared'

import config from '../config.js'
import { RUNNERS } from './job.js'

function sharedSetup () {
  Cache.setup({
    prefix: config.REDIS.PREFIX,
    cacheHost: config.REDIS.CACHE_HOST,
    persistentHost: config.REDIS.PERSISTENT_HOST,
    port: config.REDIS.port
  })
  cknex.setup('irs_990_api', config.SCYLLA.CONTACT_POINTS)
  elasticsearch.setup(`${config.ELASTICSEARCH.HOST}:9200`)
  PubSub.setup(config.REDIS.PUB_SUB_HOST, config.REDIS.PORT, config.REDIS.PUB_SUB_PREFIX)
}

async function setup () {
  sharedSetup()
  const graphqlFolders = _.filter(fs.readdirSync('./graphql'), file => file.indexOf('.') === -1)
  const scyllaTables = _.flatten(await Promise.map(graphqlFolders, async (folder) => {
    const model = await import(`../graphql/${folder}/model.js`)
    return model?.default?.getScyllaTables?.() || []
  }))
  const elasticSearchIndices = _.flatten(await Promise.map(graphqlFolders, async (folder) => {
    const model = await import(`../graphql/${folder}/model.js`)
    
    return model?.default?.getElasticSearchIndices?.() || []
  }))

  const isDev = config.ENV === config.ENVS.DEV
  const shouldRunSetup = true || (config.ENV === config.ENVS.PRODUCTION) ||
                    (config.SCYLLA.CONTACT_POINTS[0] === 'localhost')

  await Promise.all(_.filter([
    shouldRunSetup && ScyllaSetup.setup(scyllaTables, {isDev})
      .then(() => console.log('scylla setup')),
    shouldRunSetup && ElasticsearchSetup.setup(elasticSearchIndices)
      .then(() => console.log('elasticsearch setup'))
  ])).catch(err => console.log('setup', err))

  console.log('scylla & elasticsearch setup')
  cknex.enableErrors()
  JobRunner.listen(RUNNERS)
  return null // don't block
}

function childSetup () {
  sharedSetup()
  JobRunner.listen(RUNNERS)
  cknex.enableErrors()
  return Promise.resolve(null) // don't block
}

export { setup, childSetup }
