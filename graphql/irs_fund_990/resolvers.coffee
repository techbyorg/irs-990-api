{GraphqlFormatter} = require 'phil-helpers'

IrsFund990 = require './model'

module.exports = {
  Query:
    irsFund990s: (_, {ein, limit}) ->
      IrsFund990.getAllByEin ein, {limit}
      .then GraphqlFormatter.fromScylla

  IrsFund:
    irsFund990s: (irsFund, {limit}) ->
      IrsFund990.getAllByEin irsFund.ein, {limit}
      .then GraphqlFormatter.fromScylla
}
