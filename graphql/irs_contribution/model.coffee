_ = require 'lodash'
{Base, cknex, elasticsearch} = require 'phil-helpers'

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
          irs_contributions_by_toId:
            primaryKey:
              partitionKey: ['toId']
              clusteringColumns: ['year', 'fromEin', 'hash']
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

  getAllByFromEin: (fromEin) =>
    cknex().select '*'
    .from 'irs_contributions_by_fromEin_and_toId'
    .where 'fromEin', '=', fromEin
    .run()
    .map @defaultOutput

module.exports = new IrsContributionModel()
