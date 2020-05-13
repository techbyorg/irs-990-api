IrsOrg = require './model'

module.exports = {
  Query:
    irsOrg: (_, {ein}) ->
      IrsOrg.getByEin ein
}
