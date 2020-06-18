import { GraphqlFormatter } from 'backend-shared'

import IrsContribution from './model.js'

export default {
  Query: {
    irsContributions (_, { fromEin, toId, limit }) {
      if (fromEin) {
        return IrsContribution.getAllByFromEin(fromEin, { limit })
          .then(GraphqlFormatter.fromScylla)
      } else if (toId) {
        return IrsContribution.getAllByToId(toId, { limit })
          .then(GraphqlFormatter.fromScylla)
      }
    }
  },

  IrsFund: {
    irsContributions (irsFund, { limit }) {
      return IrsContribution.getAllByFromEin(irsFund.ein, { limit })
        .then(GraphqlFormatter.fromScylla)
    }
  }
}
