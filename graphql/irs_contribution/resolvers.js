{GraphqlFormatter, Loader} = require 'backend-shared'

IrsContribution = require './model'

irsContributionLoader = Loader.withContext (ids, context) ->
  IrsContribution.getAllByIds ids
  .then (irsContributions) ->
    irsContributions = _.keyBy irsContributions, 'id'
    _.map ids, (id) ->
      irsContributions[id]

module.exports = {
  Query:
    irsContributions: (_, {fromEin, toId, limit}) ->
      if fromEin
        IrsContribution.getAllByFromEin fromEin, {limit}
        .then GraphqlFormatter.fromScylla
      else if toId
        IrsContribution.getAllByToId toId, {limit}
        .then GraphqlFormatter.fromScylla

  # IrsContribution:
  #   __resolveReference: (irsContribution) ->
  #     irsContributionLoader(context).load irsContribution.id

  IrsFund:
    irsContributions: (irsFund, {limit}) ->
      IrsContribution.getAllByFromEin irsFund.ein, {limit}
      .then GraphqlFormatter.fromScylla
}
