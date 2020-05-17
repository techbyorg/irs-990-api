Promise = require 'bluebird'
_ = require 'lodash'
{JobCreate} = require 'phil-helpers'

IrsContribution = require '../../graphql/irs_contribution/model'
IrsFund = require '../../graphql/irs_fund/model'
IrsFund990 = require '../../graphql/irs_fund_990/model'
IrsOrg = require '../../graphql/irs_org/model'
IrsOrg990 = require '../../graphql/irs_org_990/model'
JobService = require '../../services/job'
config = require '../../config'

# FIXME: classify community foundatoins (990 instead of 990pf) as fund and org?

class Irs990Service
  processUnprocessedOrgs: (options) =>
    {limit = 6000, chunkSize = 300, recursive} = options
    start = Date.now()
    # 12 nodes x 2vpcu = 24 cpu * 2 concurrency = 48
    # chunk = 300. 300 * 48 = 14400
    IrsOrg990.search {
      trackTotalHits: true
      limit: limit
      query:
        bool:
          must:
            # TODO: ignore returnVersions we can't process
            range:
              importVersion:
                lt: config.CURRENT_IMPORT_VERSION
    }
    .then (orgs) =>
      console.log "Fetched #{orgs.rows.length} / #{orgs.total} in #{Date.now() - start} ms"
      start = Date.now()
      chunks = _.chunk orgs.rows, chunkSize
      await Promise.map chunks, (chunk) =>
        JobCreate.createJob {
          queue: JobService.QUEUES.DEFAULT
          waitForCompletion: true
          job: {chunk}
          type: JobService.TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK
          ttlMs: 120000
          priority: JobService.PRIORITIES.NORMAL
        }
        .catch (err) ->
          console.log 'err', err

      if orgs.total
        console.log "Finished step (#{limit}) in #{Date.now() - start} ms"
        await IrsOrg990.refreshESIndex()
        if recursive
          @processUnprocessedOrgs options
      else
        console.log 'done'


  processUnprocessedFunds: =>
    start = Date.now()
    limit = 1600
    funds = await IrsFund990.search {
      trackTotalHits: true
      limit: limit # 16 cpus, each processing 10 jobs, 160 chunks
      query:
        bool:
          must:
            range:
              importVersion:
                lt: config.CURRENT_IMPORT_VERSION
    }

    console.log "Fetched #{funds.rows.length} / #{funds.total} in #{Date.now() - start} ms"
    start = Date.now()

    # TODO: chunk + batchUpsert
    chunks = _.chunk funds.rows, 10
    await Promise.map chunks, (chunk) =>
      JobCreate.createJob {
        queue: JobService.QUEUES.DEFAULT
        waitForCompletion: true
        job: {chunk}
        type: JobService.TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK
        ttlMs: 120000
        priority: JobService.PRIORITIES.NORMAL
      }
      .catch (err) ->
        console.log 'err', err

    if funds.total
      console.log "Finished step (#{limit}) in #{Date.now() - start}, ms"
      await IrsFund990.refreshESIndex()
      @processUnprocessedFunds()
    else
      console.log 'done'


module.exports = new Irs990Service()

###
truncate irs_990_api.irs_orgs_by_ein
truncate irs_990_api.irs_orgs_990_by_ein_and_year
curl -XDELETE http://localhost:9200/irs_org_990s*
curl -XDELETE http://localhost:9200/irs_orgs*
curl -XDELETE http://localhost:9200/irs_fund_990s*
curl -XDELETE http://localhost:9200/irs_funds*
to del from prod, do same at: kubectl exec altelasticsearch-0 --namespace=production -it -- /bin/bash
###
