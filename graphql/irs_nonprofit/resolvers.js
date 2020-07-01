import _ from 'lodash'
import { GraphqlFormatter, Loader } from 'backend-shared'

import IrsNonprofit from './model.js'
import IrsNonprofit990 from '../irs_nonprofit_990/model.js'

const nonprofitLoader = Loader.withContext((eins, context) => {
  return IrsNonprofit.getAllByEins(eins)
    .then((irsNonprofits) => {
      irsNonprofits = _.keyBy(irsNonprofits, 'ein')
      return _.map(eins, ein => irsNonprofits[ein])
    })
})

export default {
  Query: {
    irsNonprofit (rootValue, { ein }) {
      return IrsNonprofit.getByEin(ein)
    },

    irsNonprofits (rootValue, { query, sort, limit }) {
      return IrsNonprofit.search({ query, sort, limit })
        .then(GraphqlFormatter.fromElasticsearch)
    }
  },

  IrsNonprofit: {
    async yearlyStats (irsNonprofit) {
      let irs990s = await IrsNonprofit990.getAllByEin(irsNonprofit.ein)
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
    async irsNonprofit (irsPerson, __, context) {
      if (irsPerson.entityType === 'nonprofit') {
        return await nonprofitLoader(context).load(irsPerson.ein)
      } else {
        return null
      }
    }
  }
}
