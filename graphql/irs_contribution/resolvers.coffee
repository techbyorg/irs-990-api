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
    irsContributions: (_, {fromEin, limit}) ->
      IrsContribution.getAllByFromEin fromEin, {limit}
      .then GraphqlFormatter.fromScylla

  IrsContribution:
    __resolveReference: (irsContribution) ->
      irsContributionLoader(context).load irsContribution.id

  IrsFund:
    irsContributions: (irsFund) ->
      IrsContribution.getAllByFromEin irsFund.ein
      .then GraphqlFormatter.fromScylla
}
