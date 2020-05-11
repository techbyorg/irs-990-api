_ = require 'lodash'

IrsOrg = require '../../graphql/irs_org/model'
JobCreateService = require '../../services/job_create'

module.exports = {
  parseGrantMakingWebsites: =>
    ({total, rows}) = await IrsOrg.search {
      trackTotalHits: true
      limit: 10000
      # limit: 10
      query:
        bool:
          must: [
            {
              match_phrase_prefix:
                website: 'http'
            }
            {
              match_phrase_prefix:
                nteecc: 'T'
            }
            {
              range:
                lastRevenue:
                  gte: 100000
            }
            {
              range:
                lastExpenses:
                  gte: 100000
            }
          ]
    }

    console.log rows.length
    # console.log JSON.stringify(_.map rows, 'name')
    fixed = _.map rows, (row) ->
      row.website = row.website.replace 'https://https', 'https://'
      row.website = row.website.replace 'http://https', 'https://'
      row.website = row.website.replace 'http://http', 'http://'
      row
    valid = _.filter fixed, ({website}) ->
      website.match(/^((https?|ftp|smtp):\/\/)?(www.)?[a-z0-9]+\.[a-z]+(\/[a-zA-Z0-9#]+\/?)*$/)
    # valid = _.take valid, 10
    _.map valid, ({ein}, i) ->
      JobCreateService.createJob {
        queueKey: 'DEFAULT'
        waitForCompletion: false
        job: {ein, counter: i}
        type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PARSE_WEBSITE
        ttlMs: 60000
        priority: JobCreateService.PRIORITIES.NORMAL
      }
      .catch (err) ->
        console.log 'err', err
}
