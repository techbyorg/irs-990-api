#!/usr/bin/env coffee
_ = require 'lodash'
log = require 'loga'
cluster = require 'cluster'
os = require 'os'

{setup, childSetup, server} = require '../'
config = require '../config'

if config.ENV is config.ENVS.PROD
  cpus = config.MAX_CPU or os.cpus().length
  if cluster.isMaster
    setup().then ->
      console.log 'setup done', cpus
      _.map _.range(cpus), ->
        console.log 'forking...'
        cluster.fork()

      cluster.on 'exit', (worker) ->
        log "Worker #{worker.id} died, respawning"
        cluster.fork()
    .catch log.error
  else
    childSetup().then ->
      server.listen config.PORT, ->
        log.info 'Worker %d, listening on %d', cluster.worker.id, config.PORT
else
  console.log 'Setting up'
  setup().then ->
    server.listen config.PORT, ->
      log.info 'Server listening on port %d', config.PORT
  .catch log.error
