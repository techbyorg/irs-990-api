// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
import { GraphqlFormatter } from 'backend-shared'
import IrsOrg from './model'

export const Query = {
  irsOrg (rootValue, { ein }) {
    return IrsOrg.getByEin(ein)
  },

  irsOrgs (rootValue, { query, limit }) {
    return IrsOrg.search({ query, limit })
      .then(GraphqlFormatter.fromElasticsearch)
  }
}
