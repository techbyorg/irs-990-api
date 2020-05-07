_ = require 'lodash'

jobQueues = require './job_queues'
JobCreateService = require './job_create'
Irs990Service = require './irs_990'
config = require '../config'

class JobRunnerService
  constructor: ->
    @queues = {
      DEFAULT:
        types:
          "#{JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK}":
            {fn: Irs990Service.processOrgChunk, concurrencyPerCpu: 10}
          "#{JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK}":
            {fn: Irs990Service.processFundChunk, concurrencyPerCpu: 10}
          "#{JobCreateService.JOB_TYPES.DEFAULT.IRS_990_UPSERT_ORGS}":
            {fn: Irs990Service.upsertOrgs, concurrencyPerCpu: 1}
          "#{JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PARSE_WEBSITE}":
            {fn: Irs990Service.parseWebsite, concurrencyPerCpu: 1}
        #   "#{JobCreateService.JOB_TYPES.DEFAULT.DAILY_UPDATE_PLACE}":
        #     {fn: PlacesService.updateDailyInfo, concurrencyPerCpu: 1}
        queue: jobQueues.DEFAULT
    }

  listen: ->
    _.forEach @queues, ({types, queue}) ->
      _.forEach types, ({fn, concurrencyPerCpu}, type) ->
        queue.process type, concurrencyPerCpu, (job) ->
          try
            fn job.data
            .catch (err) ->
              console.log 'queue err', err
              throw err
          catch err
            console.log 'queue err', err
            throw err

module.exports = new JobRunnerService()
