Queue = require 'bull'
Redis = require 'ioredis'
_ = require 'lodash'

Irs990ImporterJobs = require './irs_990_importer/jobs'
config = require '../config'

JOB_QUEUES =
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

JOB_TYPES =
  DEFAULT:
    DAILY_UPDATE_PLACE: 'monocle:default:daily_update_place'
    IRS_990_PROCESS_ORG_CHUNK: 'monocle:default:irs_990_process_org_chunk'
    IRS_990_PROCESS_FUND_CHUNK: 'monocle:default:irs_990_process_fund_chunk'
    IRS_990_UPSERT_ORGS: 'monocle:default:irs_990_upsert_orgs'
    IRS_990_PARSE_WEBSITE: 'monocle:default:irs_990_parse_website'

JOB_PRIORITIES =
  # lower (1) is higher priority
  normal: 100

JOB_RUNNERS =
  DEFAULT:
    types:
      "#{JOB_TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK}":
        {fn: Irs990ImporterJobs.processOrgChunk, concurrencyPerCpu: 10}
      "#{JOB_TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK}":
        {fn: Irs990ImporterJobs.processFundChunk, concurrencyPerCpu: 10}
      "#{JOB_TYPES.DEFAULT.IRS_990_UPSERT_ORGS}":
        {fn: Irs990ImporterJobs.upsertOrgs, concurrencyPerCpu: 1}
      "#{JOB_TYPES.DEFAULT.IRS_990_PARSE_WEBSITE}":
        {fn: Irs990ImporterJobs.parseWebsite, concurrencyPerCpu: 1}
    #   "#{JOB_TYPES.DEFAULT.DAILY_UPDATE_PLACE}":
    #     {fn: PlacesService.updateDailyInfo, concurrencyPerCpu: 1}
    queue: JOB_QUEUES.DEFAULT

module.exports = {
  QUEUES: JOB_QUEUES
  TYPES: JOB_TYPES
  PRIORITIES: JOB_PRIORITIES
  RUNNERS: JOB_RUNNERS
}
