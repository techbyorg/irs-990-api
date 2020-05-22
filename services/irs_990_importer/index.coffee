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
  processEin: (ein, {type}) =>
    Model = if type is 'fund' then IrsFund990 else IrsOrg990
    chunk = await Model.getAllByEin ein
    JobCreate.createJob {
      queue: JobService.QUEUES.DEFAULT
      waitForCompletion: true
      job: {chunk}
      type: if type is 'fund' \
            then JobService.TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK \
            else JobService.TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK
      ttlMs: 120000
      priority: JobService.PRIORITIES.NORMAL
    }

  processUnprocessed: (options) =>
    {limit = 6000, chunkSize = 300, chunkConcurrency, recursive,
      Model990, jobType} = options
    start = Date.now()
    Model990.search {
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
    .then (model990s) =>
      console.log "Fetched #{model990s.rows.length} / #{model990s.total} in #{Date.now() - start} ms"
      start = Date.now()
      chunks = _.chunk model990s.rows, chunkSize
      await Promise.map chunks, (chunk) =>
        JobCreate.createJob {
          queue: JobService.QUEUES.DEFAULT
          waitForCompletion: true
          job: {chunk, chunkConcurrency}
          type: jobType
          ttlMs: 120000
          priority: JobService.PRIORITIES.NORMAL
        }
        .catch (err) ->
          console.log 'err', err

      if model990s.total
        console.log "Finished step (#{limit}) in #{Date.now() - start} ms"
        await Model990.refreshESIndex()
        if recursive
          @processUnprocessed options
      else
        console.log 'done'

  processUnprocessedOrgs: ({limit, chunkSize, chunkConcurrency, recursive}) =>
    @processUnprocessed {
      limit, chunkSize, chunkConcurrency, recursive, Model990: IrsOrg990
      jobType: JobService.TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK
    }


  processUnprocessedFunds: ({limit, chunkSize, chunkConcurrency, recursive}) =>
    @processUnprocessed {
      limit, chunkSize, chunkConcurrency, recursive, Model990: IrsFund990
      jobType: JobService.TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK
    }



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
