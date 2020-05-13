IrsContribution = require './model'
{Loader} = require 'phil-helpers'

irsContributionLoader = Loader.withContext (ids, context) ->
  IrsContribution.getAllByIds ids
  .then (irsContributions) ->
    irsContributions = _.keyBy irsContributions, 'id'
    _.map ids, (id) ->
      irsContributions[id]

module.exports = {
  Query:
    irsContributions: (_, {ein}) ->
      IrsContribution.getAllByFromEin ein

  IrsContribution:
    __resolveReference: (irsContribution) ->
      irsContributionLoader(context).load irsContribution.id
}
