import _ from 'lodash'
import { JobCreate } from 'backend-shared'

import IrsOrg from '../../graphql/irs_org/model.js'
import JobService from '../../services/job.js'

export const parseGrantMakingWebsites = async () => {
  const { rows } = await IrsOrg.search({
    trackTotalHits: true,
    limit: 10000,
    // limit: 10
    query: {
      bool: {
        must: [
          {
            match_phrase_prefix: {
              website: 'http'
            }
          },
          {
            match_phrase_prefix: {
              nteecc: 'T'
            }
          },
          {
            range: {
              lastRevenue: {
                gte: 100000
              }
            }
          },
          {
            range: {
              lastExpenses: {
                gte: 100000
              }
            }
          }
        ]
      }
    }
  })

  console.log(rows.length)
  // console.log JSON.stringify(_.map rows, 'name')
  const fixed = _.map(rows, function (row) {
    row.website = row.website.replace('https://https', 'https://')
    row.website = row.website.replace('http://https', 'https://')
    row.website = row.website.replace('http://http', 'http://')
    return row
  })
  const valid = _.filter(fixed, ({ website }) => website.match(/^((https?|ftp|smtp):\/\/)?(www.)?[a-z0-9]+\.[a-z]+(\/[a-zA-Z0-9#]+\/?)*$/))
  // valid = _.take valid, 10
  return _.map(valid, ({ ein }, i) => JobCreate.createJob({
    queue: JobService.QUEUES.DEFAULT,
    waitForCompletion: true,
    job: { ein, counter: i },
    type: JobService.TYPES.DEFAULT.IRS_990_PARSE_WEBSITE,
    ttlMs: 60000,
    priority: JobService.PRIORITIES.NORMAL
  }).catch(err => console.log('err', err)))
}
