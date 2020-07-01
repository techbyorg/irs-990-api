import Queue from 'bull'

import Irs990ImporterJobs from './irs_990_importer/jobs.js'
import config from '../config.js'

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
    IRS_990_PROCESS_NONPROFIT_CHUNK: 'irs_990_api:default:irs_990_process_nonprofit_chunk',
    IRS_990_PROCESS_FUND_CHUNK: 'irs_990_api:default:irs_990_process_fund_chunk',
    IRS_990_UPSERT_NONPROFITS: 'irs_990_api:default:irs_990_upsert_nonprofits',
    IRS_990_PARSE_WEBSITE: 'irs_990_api:default:irs_990_parse_website'
  }
}

const JOB_PRIORITIES =
  // lower (1) is higher priority
  { normal: 100 }

const JOB_RUNNERS = {
  DEFAULT: {
    types: {
      [JOB_TYPES.DEFAULT.IRS_990_PROCESS_NONPROFIT_CHUNK]:
        { fn: Irs990ImporterJobs.processNonprofitChunk, concurrencyPerCpu: 2 },
      [JOB_TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK]:
        { fn: Irs990ImporterJobs.processFundChunk, concurrencyPerCpu: 2 },
      [JOB_TYPES.DEFAULT.IRS_990_UPSERT_NONPROFITS]:
        { fn: Irs990ImporterJobs.upsertNonprofits, concurrencyPerCpu: 2 },
      [JOB_TYPES.DEFAULT.IRS_990_PARSE_WEBSITE]:
        { fn: Irs990ImporterJobs.parseWebsite, concurrencyPerCpu: 1 }
    },
    //   "#{JOB_TYPES.DEFAULT.DAILY_UPDATE_PLACE}":
    //     {fn: PlacesService.updateDailyInfo, concurrencyPerCpu: 1}
    queue: JOB_QUEUES.DEFAULT
  }
}

export {
  JOB_QUEUES as QUEUES,
  JOB_TYPES as TYPES,
  JOB_PRIORITIES as PRIORITIES,
  JOB_RUNNERS as RUNNERS
}
