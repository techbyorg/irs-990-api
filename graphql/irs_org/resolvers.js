import { GraphqlFormatter } from 'backend-shared'

import IrsOrg from './model.js'

export const Query = {
  irsOrg (rootValue, { ein }) {
    return IrsOrg.getByEin(ein)
  },

  irsOrgs (rootValue, { query, limit }) {
    return IrsOrg.search({ query, limit })
      .then(GraphqlFormatter.fromElasticsearch)
  }
}
