_ = require 'lodash'
{cknex, GraphqlFormatter} = require 'phil-helpers'

IrsFund = require './model'
IrsFund990 = require '../irs_fund_990/model'
IrsContribution = require '../irs_contribution/model'

module.exports = {
  Query:
    irsFund: (rootValue, {ein}) ->
      IrsFund.getByEin ein

    irsFunds: (rootValue, {query, limit}) ->
      IrsFund.search {query, limit}
      .then GraphqlFormatter.fromElasticsearch

  IrsFund:
    yearlyStats: (irsFund) ->
      console.log 'get'
      irs990s = await IrsFund990.getAllByEin irsFund.ein
      irs990s = _.orderBy irs990s, 'year'
      {
        years: _.map irs990s, (irs990) ->
          {
            year: irs990.year
            assets: irs990.assets.eoy
          }
      }

    contributionStats: (irsFund) ->
      contributions = await IrsContribution.getAllByFromEin irsFund.ein
      # TODO: cache result
      contributionsByState = _.groupBy contributions, 'toState'
      states = _.mapValues contributionsByState, (contributions) ->
        sum = _.reduce contributions, (long, {amount}) ->
          long.add amount
        , cknex.Long.fromValue(0)
        {sum, count: contributions.length}
      {states}
}
