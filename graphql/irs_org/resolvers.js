import { GraphqlFormatter } from 'backend-shared';
import IrsOrg from './model';

export let Query = {
  irsOrg(rootValue, {ein}) {
    return IrsOrg.getByEin(ein);
  },

  irsOrgs(rootValue, {query, limit}) {
    return IrsOrg.search({query, limit})
    .then(GraphqlFormatter.fromElasticsearch);
  }
};
