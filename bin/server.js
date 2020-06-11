#!/usr/bin/env nodeimport _ from 'lodash';
import log from 'loga';
import cluster from 'cluster';
import os from 'os';
import { setup, childSetup, server } from '../';
import config from '../config';

if (config.ENV === config.ENVS.PROD) {
  const cpus = config.MAX_CPU || os.cpus().length;
  if (cluster.isMaster) {
    setup().then(function() {
      console.log('setup done', cpus);
      _.map(_.range(cpus), function() {
        console.log('forking...');
        return cluster.fork();
      });

      return cluster.on('exit', function(worker) {
        log(`Worker ${worker.id} died, respawning`);
        return cluster.fork();
      });}).catch(log.error);
  } else {
    childSetup().then(() => server.listen(config.PORT, () => log.info('Worker %d, listening on %d', cluster.worker.id, config.PORT)));
  }
} else {
  console.log('Setting up');
  setup().then(() => server.listen(config.PORT, () => log.info('Server listening on port %d', config.PORT))).catch(log.error);
}
