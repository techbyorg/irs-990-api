IrsContribution = require './model'

module.exports = {
  Query:
    irsContributions: (_, {ein}) ->
      IrsContribution.getAllByFromEin ein
}
