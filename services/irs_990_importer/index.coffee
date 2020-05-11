Promise = require 'bluebird'
_ = require 'lodash'

IrsContribution = require '../../graphql/irs_contribution/model'
IrsFund = require '../../graphql/irs_fund/model'
IrsFund990 = require '../../graphql/irs_fund_990/model'
IrsOrg = require '../../graphql/irs_org/model'
IrsOrg990 = require '../../graphql/irs_org_990/model'
JobCreateService = require '../../services/job_create'

class Irs990Service
  processUnprocessedOrgs: =>
    start = Date.now()
    IrsOrg990.search {
      trackTotalHits: true
      limit: 160 # 16 cpus, 16 chunks
      query:
        bool:
          must:
            term:
              isProcessed: false
    }
    .then (orgs) =>
      console.log orgs.total, 'time', Date.now() - start
      chunks = _.chunk orgs.rows, 10
      Promise.map chunks, (chunk) =>
        JobCreateService.createJob {
          queueKey: 'DEFAULT'
          waitForCompletion: true
          job: {chunk}
          type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK
          ttlMs: 60000
          priority: JobCreateService.PRIORITIES.NORMAL
        }
        .catch (err) ->
          console.log 'err', err
      .then =>
        if orgs.total
          console.log 'done step'
          @processUnprocessedOrgs()
        else
          console.log 'done'


  processUnprocessedFunds: =>
    start = Date.now()
    IrsFund990.search {
      trackTotalHits: true
      limit: 80 # 16 cpus, 16 chunks
      query:
        bool:
          must:
            term:
              isProcessed: false
    }
    .then (funds) =>
      console.log funds.total, 'time', Date.now() - start

      # TODO: chunk + batchUpsert
      chunks = _.chunk funds.rows, 5
      Promise.map chunks, (chunk) =>
        JobCreateService.createJob {
          queueKey: 'DEFAULT'
          waitForCompletion: true
          job: {chunk}
          type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK
          ttlMs: 60000
          priority: JobCreateService.PRIORITIES.NORMAL
        }
        .catch (err) ->
          console.log 'err', err
      .then =>
        if funds.total
          console.log 'done step'
          @processUnprocessedFunds()
        else
          console.log 'done'

  # TODO: rm
  setLastYearContributions: ->
    IrsFund.search {
      trackTotalHits: true
      limit: 10000
      query:
        bool:
          must_not:
            exists:
              field: 'lastContributions'
    }
    .then ({total, rows}) ->
      console.log total
      Promise.map rows, (row, i) ->
        console.log i
        IrsContribution.getByAllByFromEin row.ein
        .then (contributions) ->
          # console.log contributions
          recentYear = _.maxBy(contributions, 'year')?.year
          if recentYear
            contributions = _.filter contributions, {year: recentYear}
            amount = _.sumBy contributions, ({amount}) -> parseInt amount
          amount ?= 0
          # console.log amount
          IrsFund.upsertByRow row, {lastContributions: amount}

      , {concurrency: 10}


module.exports = new Irs990Service()

###
truncate irs_990_api.irs_orgs_by_ein
truncate irs_990_api.irs_orgs_990_by_ein_and_year
curl -XDELETE http://10.245.244.135:9200/irs_org_990s*
curl -XDELETE http://10.245.244.135:9200/irs_orgs*
curl -XDELETE http://10.245.244.135:9200/irs_fund_990s*
curl -XDELETE http://10.245.244.135:9200/irs_funds*
###
# module.exports.setLastYearContributions()
# module.exports.getEinFromNameCityState 'confett Foundation', 'denver', 'co'
