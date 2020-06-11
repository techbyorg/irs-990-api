import fs from 'fs'
import _ from 'lodash'
import Promise from 'bluebird'
import { cknex, ElasticsearchSetup, JobRunner, ScyllaSetup } from 'backend-shared'

import config from '../config.js'
import { RUNNERS } from './job.js'

async function setup () {
  cknex.setDefaultKeyspace('irs_990_api')
  const graphqlFolders = _.filter(fs.readdirSync('./graphql'), file => file.indexOf('.') === -1)
  const scyllaTables = await Promise.map(graphqlFolders, async (folder) => {
    const model = await import(`../graphql/${folder}/model`)
    return model?.getScyllaTables?.() || []
  })
  const elasticSearchIndices = await Promise.map(graphqlFolders, async (folder) => {
    const model = await import(`../graphql/${folder}/model`)
    return model?.getElasticSearchIndices?.() || []
  })

  const shouldRunSetup = true || (config.get().ENV === config.get().ENVS.PRODUCTION) ||
                    (config.get().SCYLLA.CONTACT_POINTS[0] === 'localhost')

  await Promise.all(_.filter([
    shouldRunSetup && ScyllaSetup.setup(scyllaTables)
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
  cknex.setDefaultKeyspace('irs_990_api')
  JobRunner.listen(RUNNERS)
  cknex.enableErrors()
  return Promise.resolve(null) // don't block
}

export { setup, childSetup }
