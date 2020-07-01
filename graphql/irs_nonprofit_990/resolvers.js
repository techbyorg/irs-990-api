import { GraphqlFormatter } from 'backend-shared'

import IrsNonprofit990 from './model.js'

export default {
  Query: {
    irsNonprofit990s (rootValue, { ein, query, limit }) {
      if (ein) {
        return IrsNonprofit990.getAllByEin(ein, { limit })
          .then(GraphqlFormatter.fromScylla)
      } else {
        return IrsNonprofit990.search({ query, limit })
          .then(GraphqlFormatter.fromElasticsearch)
      }
    }
  },

  IrsNonprofit: {
    irsNonprofit990s (irsNonprofit, { limit }) {
      return IrsNonprofit990.getAllByEin(irsNonprofit.ein, { limit })
        .then(GraphqlFormatter.fromScylla)
    }
  }
}
