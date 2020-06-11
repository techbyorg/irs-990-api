import cluster from 'cluster'
import os from 'os'
import _ from 'lodash'

import { setup, childSetup, serverPromise } from '../index.js'
import config from '../config.js'

if (config.ENV === config.ENVS.PROD) {
  const cpus = config.MAX_CPU || os.cpus().length
  if (cluster.isMaster) {
    setup().then(function () {
      console.log('setup done', cpus)
      _.map(_.range(cpus), function () {
        console.log('forking...')
        return cluster.fork()
      })

      return cluster.on('exit', function (worker) {
        console.log(`Worker ${worker.id} died, respawning`)
        return cluster.fork()
      })
    }).catch(console.log)
  } else {
    childSetup().then(async () => {
      const server = await serverPromise
      server.listen(config.PORT, () =>
        console.log('Worker %d, listening on %d', cluster.worker.id, config.PORT)
      )
    })
  }
} else {
  console.log('Setting up')
  setup().then(async () => {
    const server = await serverPromise
    server.listen(config.PORT, () =>
      console.log('Server listening on port %d', config.PORT)
    )
  }).catch(console.log)
}
