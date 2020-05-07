IrsPerson = require './model'

module.exports = {
  Query:
    irsPersons: (_, {ein}) ->
      IrsPerson.getAllByEin ein
}
