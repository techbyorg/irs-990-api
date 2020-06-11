// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
import { GraphqlFormatter } from 'backend-shared'
import IrsOrg990 from './model'

export const Query = {
  irsOrg990s (rootValue, { ein, query, limit }) {
    if (ein) {
      return IrsOrg990.getAllByEin(ein, { limit })
        .then(GraphqlFormatter.fromScylla)
    } else {
      return IrsOrg990.search({ query, limit })
        .then(GraphqlFormatter.fromElasticsearch)
    }
  }
}

export const IrsOrg = {
  irsOrg990s (irsOrg, { limit }) {
    return IrsOrg990.getAllByEin(irsOrg.ein, { limit })
      .then(GraphqlFormatter.fromScylla)
  }
}
