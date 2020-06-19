import _ from 'lodash'
import { GraphqlFormatter, Loader } from 'backend-shared'

import IrsOrg from './model.js'
import IrsOrg990 from '../irs_org_990/model.js'

const orgLoader = Loader.withContext((eins, context) => {
  return IrsOrg.getAllByEins(eins)
    .then((irsOrgs) => {
      irsOrgs = _.keyBy(irsOrgs, 'ein')
      return _.map(eins, ein => irsOrgs[ein])
    })
})

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
  },

  IrsPerson: {
    async irsOrg (irsPerson, __, context) {
      if (irsPerson.entityType === 'org') {
        return await orgLoader(context).load(irsPerson.ein)
      } else {
        return null
      }
    }
  }
}
