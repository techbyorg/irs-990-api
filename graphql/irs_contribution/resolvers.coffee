{GraphqlFormatter, Loader} = require 'phil-helpers'

IrsContribution = require './model'

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
      .then GraphqlFormatter.fromScylla

  IrsContribution:
    __resolveReference: (irsContribution) ->
      irsContributionLoader(context).load irsContribution.id
}
