{GraphqlFormatter} = require 'phil-helpers'

IrsOrg990 = require './model'

module.exports = {
  Query:
    irsOrg990s: (rootValue, {ein, query}) ->
      if ein
        IrsOrg990.getAllByEin ein
        .then GraphqlFormatter.fromScylla
      else
        IrsOrg990.search {query}
        .then GraphqlFormatter.fromElasticsearch

  IrsOrg:
    irsOrg990s: (rootValue) ->
      IrsOrg990.getAllByEin rootValue.ein
      .then GraphqlFormatter.fromScylla
}
