import _ from 'lodash'
import { GraphqlFormatter } from 'backend-shared'

import IrsFund from './model.js'
import IrsFund990 from '../irs_fund_990/model.js'

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
  }
}
