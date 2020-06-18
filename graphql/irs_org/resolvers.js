import _ from 'lodash'
import { GraphqlFormatter } from 'backend-shared'

import IrsOrg from './model.js'
import IrsOrg990 from '../irs_org_990/model.js'

export default {
  Query: {
    irsOrg (rootValue, { ein }) {
      return IrsOrg.getByEin(ein)
    },

    irsOrgs (rootValue, { query, sort, limit }) {
      return IrsOrg.search({ query, sort, limit })
        .then(GraphqlFormatter.fromElasticsearch)
    }
  },

  IrsOrg: {
    async yearlyStats (irsOrg) {
      let irs990s = await IrsOrg990.getAllByEin(irsOrg.ein)
      irs990s = _.orderBy(irs990s, 'year')
      return {
        years: _.map(irs990s, irs990 => ({
          year: irs990.year,
          assets: irs990.assets?.eoy,
          employeeCount: irs990.employeeCount,
          volunteerCount: irs990.volunteerCount
        }))
      }
    }
  }
}
