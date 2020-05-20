{GraphqlFormatter} = require 'phil-helpers'

IrsFund = require './model'

module.exports = {
  Query:
    irsFund: (rootValue, {ein}) ->
      IrsFund.getByEin ein

    irsFunds: (rootValue, {query, limit}) ->
      IrsFund.search {query, limit}
      .then GraphqlFormatter.fromElasticsearch
}
