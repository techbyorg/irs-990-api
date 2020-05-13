IrsOrg = require './model'

module.exports = {
  Query:
    irsOrg: (_, {ein}) ->
      Promise.resolve {ein: 'abc'}
      # IrsOrg.getByEin ein
}
