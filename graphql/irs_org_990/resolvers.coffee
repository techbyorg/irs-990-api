{GraphqlFormatter} = require 'backend-shared'

IrsOrg990 = require './model'

module.exports = {
  Query:
    irsOrg990s: (rootValue, {ein, query, limit}) ->
      if ein
        IrsOrg990.getAllByEin ein, {limit}
        .then GraphqlFormatter.fromScylla
      else
        IrsOrg990.search {query, limit}
        .then GraphqlFormatter.fromElasticsearch

  IrsOrg:
    irsOrg990s: (irsOrg, {limit}) ->
      IrsOrg990.getAllByEin irsOrg.ein, {limit}
      .then GraphqlFormatter.fromScylla
}
