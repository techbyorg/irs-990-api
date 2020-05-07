IrsOrg990 = require './model'

module.exports = {
  Query:
    irsOrg990s: (_, {ein}) ->
      IrsOrg990.getAllByEin ein
}
