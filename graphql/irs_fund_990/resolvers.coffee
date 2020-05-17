{GraphqlFormatter} = require 'phil-helpers'

IrsFund990 = require './model'

module.exports = {
  Query:
    irsFund990s: (_, {ein}) ->
      IrsFund990.getAllByEin ein
      .then GraphqlFormatter.fromScylla
}
