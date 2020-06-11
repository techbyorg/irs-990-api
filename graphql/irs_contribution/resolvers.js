/* eslint-disable
    no-undef,
    no-unused-vars,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
import { GraphqlFormatter, Loader } from 'backend-shared'
import IrsContribution from './model'

const irsContributionLoader = Loader.withContext((ids, context) => IrsContribution.getAllByIds(ids)
  .then(function (irsContributions) {
    irsContributions = _.keyBy(irsContributions, 'id')
    return _.map(ids, id => irsContributions[id])
  }))

export const Query = {
  irsContributions (_, { fromEin, toId, limit }) {
    if (fromEin) {
      return IrsContribution.getAllByFromEin(fromEin, { limit })
        .then(GraphqlFormatter.fromScylla)
    } else if (toId) {
      return IrsContribution.getAllByToId(toId, { limit })
        .then(GraphqlFormatter.fromScylla)
    }
  }
}

export const IrsFund = {
  irsContributions (irsFund, { limit }) {
    return IrsContribution.getAllByFromEin(irsFund.ein, { limit })
      .then(GraphqlFormatter.fromScylla)
  }
}
