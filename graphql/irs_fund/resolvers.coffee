{GraphqlFormatter} = require 'phil-helpers'

IrsFund = require './model'

module.exports = {
  Query:
    irsFund: (rootValue, {ein}) ->
      IrsFund.getByEin ein

    irsFunds: (rootValue, {query}) ->
      IrsFund.search {query}
      .then GraphqlFormatter.fromElasticsearch
}
