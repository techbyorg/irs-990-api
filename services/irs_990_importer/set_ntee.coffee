_ = require 'lodash'
requestNonPromise = require 'request'
csv = require 'csvtojson'
fs = require 'fs'
{JobCreate} = require 'backend-shared'

IrsOrg = require '../../graphql/irs_org/model'
JobService = require '../../services/job'
config = require '../../config'

module.exports = {
  setNtee: ->
    console.log 'sync'
    cache = null
    requestNonPromise(config.NTEE_CSV)
    .pipe(fs.createWriteStream('data.csv'))
    .on 'finish', ->
      console.log 'file downloaded'
      chunk = []
      i = 0
      csv().fromFile('data.csv')
      .subscribe ((json) ->
        i += 1
        # batch every 100 for upsert
        if i and not (i % 100)
          console.log i
          cache = chunk
          chunk = []
          JobCreate.createJob {
            queue: JobService.QUEUES.DEFAULT
            waitForCompletion: true
            job: {orgs: cache, i}
            type: JobService.TYPES.DEFAULT.IRS_990_UPSERT_ORGS
            ttlMs: 60000
            priority: JobService.PRIORITIES.NORMAL
          }
          .catch (err) ->
            console.log 'err', err

        chunk.push {
          ein: json.EIN
          name: json.NAME
          city: json.CITY
          state: json.STATE
          nteecc: json.NTEECC
        }
      ), (-> console.log 'error'), ->
        console.log 'done'
        IrsOrg.batchUpsert cache
}
