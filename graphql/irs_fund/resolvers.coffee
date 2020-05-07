IrsFund = require './model'

module.exports = {
  Query:
    irsFund: (_, {ein}) ->
      IrsFund.getByEin ein
}
