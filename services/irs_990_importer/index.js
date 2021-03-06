import Promise from 'bluebird'
import _ from 'lodash'
import { JobCreate } from 'backend-shared'

import IrsFund from '../../graphql/irs_fund/model.js'
import IrsFund990 from '../../graphql/irs_fund_990/model.js'
import IrsNonprofit990 from '../../graphql/irs_nonprofit_990/model.js'
import * as JobService from '../../services/job.js'
import config from '../../config.js'

// FIXME: classify community foundatoins (990 instead of 990pf) as fund and nonprofit?

export async function processEin (ein, { type }) {
  const Model990 = type === 'fund' ? IrsFund990 : IrsNonprofit990
  const chunk = await Model990.getAllByEin(ein)
  return JobCreate.createJob({
    queue: JobService.QUEUES.DEFAULT,
    waitForCompletion: true,
    job: { chunk },
    type: type === 'fund'
      ? JobService.TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK
      : JobService.TYPES.DEFAULT.IRS_990_PROCESS_NONPROFIT_CHUNK,
    ttlMs: 120000,
    priority: JobService.PRIORITIES.NORMAL
  })
}

// some large funds need to be processed 1 by 1 to not overload scylla
export async function fixBadFundImports ({ limit = 10000 }) {
  const irsFunds = await IrsFund.search({
    trackTotalHits: true,
    limit,
    query: {
      bool: {
        must: [
          {
            range: {
              'lastYearStats.grants': { gt: 1 }
            }
          },
          {
            range: {
              assets: { gt: 100000000 }
            }
          }
        ]
      }
    }
  })
  console.log(`Fetched ${irsFunds.rows.length} / ${irsFunds.total}`)
  return Promise.each(irsFunds.rows, irsFund => {
    return processEin(irsFund.ein, { type: 'fund' })
  })
    .then(() => console.log('done all'))
}

export async function processUnprocessed (options) {
  const {
    limit = 6000, chunkSize = 300, chunkConcurrency, recursive,
    Model990, jobType
  } = options
  let start = Date.now()
  const model990s = await Model990.search({
    trackTotalHits: true,
    limit,
    query: {
      bool: {
        // should: _.map config.VALID_RETURN_VERSIONS, (version) ->
        //   match: returnVersion: version
        must: {
          range: {
            // 'assets.eoy': gt: 100000000
            importVersion: { lt: config.CURRENT_IMPORT_VERSION }
          }
        }
      }
    }
  })
  console.log(`Fetched ${model990s.rows.length} / ${model990s.total} in ${Date.now() - start} ms`)
  start = Date.now()
  const chunks = _.chunk(model990s.rows, chunkSize)
  await Promise.map(chunks, chunk => {
    return JobCreate.createJob({
      queue: JobService.QUEUES.DEFAULT,
      waitForCompletion: true,
      job: { chunk, chunkConcurrency },
      type: jobType,
      ttlMs: 120000,
      priority: JobService.PRIORITIES.NORMAL
    })
      .catch(err => console.log('err', err))
  })

  if (model990s.total) {
    console.log(`Finished step (${limit}) in ${Date.now() - start} ms`)
    await Model990.refreshESIndex()
    if (recursive) {
      return processUnprocessed(options)
    }
  } else {
    return console.log('done')
  }
}

export function processUnprocessedNonprofits ({ limit, chunkSize, chunkConcurrency, recursive }) {
  return processUnprocessed({
    limit,
    chunkSize,
    chunkConcurrency,
    recursive,
    Model990: IrsNonprofit990,
    jobType: JobService.TYPES.DEFAULT.IRS_990_PROCESS_NONPROFIT_CHUNK
  })
}

export function processUnprocessedFunds ({ limit, chunkSize, chunkConcurrency, recursive }) {
  return processUnprocessed({
    limit,
    chunkSize,
    chunkConcurrency,
    recursive,
    Model990: IrsFund990,
    jobType: JobService.TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK
  })
}
/*
truncate irs_990_api.irs_orgs_by_ein
truncate irs_990_api.irs_orgs_990_by_ein_and_year
curl -XDELETE http://localhost:9200/irs_org_990s*
curl -XDELETE http://localhost:9200/irs_orgs*
curl -XDELETE http://localhost:9200/irs_fund_990s*
curl -XDELETE http://localhost:9200/irs_funds*
to del from prod, do same at: kubectl exec altelasticsearch-0 --namespace=production -it -- /bin/bash
*/
