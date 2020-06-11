_ = require 'lodash'
{Base, cknex, elasticsearch} = require 'backend-shared'

config = require '../../config'

# example 990pf: https://s3.amazonaws.com/irs-form-990/201533209349101373_public.xml

class IrsContributionModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_contributions_by_fromEin_and_toId'
        keyspace: 'irs_990_api'
        fields:
          year: 'int'
          fromEin: 'text'
          toId: 'text' # ein or name if no ein
          toName: 'text'
          hash: 'text' # unique identifier if multiple to same toId in a year
          # ^^ md5 year, toName, toCity, toState, purpose, amount
          toExemptStatus: 'text'
          toCity: 'text'
          toState: 'text'
          amount: 'bigint'
          type: 'text' # org | person
          nteeMajor: {type: 'text', defaultFn: -> '?'}
          nteeMinor: {type: 'text', defaultFn: -> '?'}
          relationship: 'text'
          purpose: 'text'
        primaryKey:
          partitionKey: ['fromEin']
          clusteringColumns: ['toId', 'year', 'hash']
        materializedViews:
          irs_contributions_by_fromEin_and_ntee:
            primaryKey:
              partitionKey: ['fromEin']
              clusteringColumns: ['nteeMajor', 'toId', 'year', 'hash']
          irs_contributions_by_fromEin_and_year:
            primaryKey:
              partitionKey: ['fromEin']
              clusteringColumns: ['year', 'toId', 'hash']
            withClusteringOrderBy: [['year', 'desc'], ['toId', 'asc']]
          irs_contributions_by_toId:
            primaryKey:
              partitionKey: ['toId']
              clusteringColumns: ['year', 'fromEin', 'hash']
            withClusteringOrderBy: ['year', 'desc']
      }
    ]

  getElasticSearchIndices: ->
    [
      {
        name: 'irs_contributions'
        mappings:
          fromEin: {type: 'keyword'}
          year: {type: 'integer'}
          toId: {type: 'keyword'} # ein or name if no ein
          toName: {type: 'text'}
          hash: {type: 'text'}
          toExemptStatus: {type: 'keyword'}
          toCity: {type: 'keyword'}
          toState: {type: 'keyword'}
          amount: {type: 'long'}
          nteeMajor: {type: 'keyword'}
          nteeMinor: {type: 'keyword'}
          relationship: {type: 'text'}
          purpose: {type: 'text'}
      }
    ]

  getAllByFromEin: (fromEin, {limit} = {}) =>
    q = cknex().select '*'
    .from 'irs_contributions_by_fromEin_and_year'
    .where 'fromEin', '=', fromEin
    if limit
      q.limit limit
    q.run()
    .map @defaultOutput

  getAllByToId: (toId, {limit} = {}) =>
    q = cknex().select '*'
    .from 'irs_contributions_by_toId'
    .where 'toId', '=', toId
    .run()
    .then (irsContributions) ->
      irsContributions.reverse()
      if limit
        _.take irsContributions, limit
      else
        irsContributions
    # TODO: limit in scylla, not node once withclusteringorderby is done
    # if limit
    #   q.limit limit
    # q.run()
    .map @defaultOutput

  getAllFromEinsFromToEins: (toIds) ->
    q = cknex().select 'fromEin', 'toId', 'amount'
    .from 'irs_contributions_by_toId'
    .where 'toId', 'IN', toIds
    .run()

module.exports = new IrsContributionModel()
