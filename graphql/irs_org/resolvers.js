{GraphqlFormatter} = require 'backend-shared'

IrsOrg = require './model'

module.exports = {
  Query:
    irsOrg: (rootValue, {ein}) ->
      IrsOrg.getByEin ein

    irsOrgs: (rootValue, {query, limit}) ->
      IrsOrg.search {query, limit}
      .then GraphqlFormatter.fromElasticsearch
}
