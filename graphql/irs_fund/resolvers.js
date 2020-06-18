import _ from 'lodash'
import { GraphqlFormatter, Loader } from 'backend-shared'

import IrsFund from './model.js'
import IrsFund990 from '../irs_fund_990/model.js'

const fundLoader = Loader.withContext((eins, context) => {
  return IrsFund.getAllByEins(eins)
    .then((irsFunds) => {
      irsFunds = _.keyBy(irsFunds, 'ein')
      return _.map(eins, ein => irsFunds[ein])
    })
})

export default {
  Query: {
    irsFund (rootValue, { ein }) {
      return IrsFund.getByEin(ein)
    },

    irsFunds (rootValue, { query, sort, limit }) {
      return IrsFund.search({ query, sort, limit })
        .then(GraphqlFormatter.fromElasticsearch)
    }
  },

  IrsFund: {
    async yearlyStats (irsFund) {
      let irs990s = await IrsFund990.getAllByEin(irsFund.ein)
      irs990s = _.orderBy(irs990s, 'year')
      return {
        years: _.map(irs990s, irs990 => ({
          year: irs990.year,
          assets: irs990.assets?.eoy,
          grantSum: irs990.expenses?.contributionsAndGrants,
          officerSalaries: irs990.expenses?.officerSalaries
        }))
      }
    }
  },

  IrsContribution: {
    async irsFund (irsContribution, __, context) {
      return await fundLoader(context).load(irsContribution.fromEin)
    }
  }
}
