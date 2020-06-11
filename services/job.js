/* eslint-disable
    no-unused-vars,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
import Queue from 'bull'
import Redis from 'ioredis'
import _ from 'lodash'
import Irs990ImporterJobs from './irs_990_importer/jobs'
import config from '../config'

const JOB_QUEUES = {
  DEFAULT:
    new Queue('irs_990_api_DEFAULT', {
      redis: {
        port: config.REDIS.PORT,
        host: config.REDIS.REDIS_PUB_SUB_HOST || config.REDIS.CACHE_HOST
      },
      limiter: { // 100 calls per second
        max: 100,
        duration: 1000
      }
    })
}

const JOB_TYPES = {
  DEFAULT: {
    DAILY_UPDATE_PLACE: 'irs_990_api:default:daily_update_place',
    IRS_990_PROCESS_ORG_CHUNK: 'irs_990_api:default:irs_990_process_org_chunk',
    IRS_990_PROCESS_FUND_CHUNK: 'irs_990_api:default:irs_990_process_fund_chunk',
    IRS_990_UPSERT_ORGS: 'irs_990_api:default:irs_990_upsert_orgs',
    IRS_990_PARSE_WEBSITE: 'irs_990_api:default:irs_990_parse_website'
  }
}

const JOB_PRIORITIES =
  // lower (1) is higher priority
  { normal: 100 }

const JOB_RUNNERS = {
  DEFAULT: {
    types: {
      [JOB_TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK]:
        { fn: Irs990ImporterJobs.processOrgChunk, concurrencyPerCpu: 2 },
      [JOB_TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK]:
        { fn: Irs990ImporterJobs.processFundChunk, concurrencyPerCpu: 2 },
      [JOB_TYPES.DEFAULT.IRS_990_UPSERT_ORGS]:
        { fn: Irs990ImporterJobs.upsertOrgs, concurrencyPerCpu: 2 },
      [JOB_TYPES.DEFAULT.IRS_990_PARSE_WEBSITE]:
        { fn: Irs990ImporterJobs.parseWebsite, concurrencyPerCpu: 1 }
    },
    //   "#{JOB_TYPES.DEFAULT.DAILY_UPDATE_PLACE}":
    //     {fn: PlacesService.updateDailyInfo, concurrencyPerCpu: 1}
    queue: JOB_QUEUES.DEFAULT
  }
}

export { JOB_QUEUES as QUEUES, JOB_TYPES as TYPES, JOB_PRIORITIES as PRIORITIES, JOB_RUNNERS as RUNNERS }
