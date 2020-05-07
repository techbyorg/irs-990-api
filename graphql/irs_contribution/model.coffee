_ = require 'lodash'

Base = require '../base_model'
CacheService = require '../../services/cache'
cknex = require '../../services/cknex'
elasticsearch = require '../../services/elasticsearch'
config = require '../../config'

# FIXME FIXME FIXME: flaw where multiple contributions to same org are only counted once

class IrsContributionModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_contributions_by_fromEin_and_toId'
        keyspace: 'monocle'
        fields:
          id: 'timeuuid'
          year: 'int'
          fromEin: 'text'
          toId: 'text' # ein or name if no ein
          toName: 'text'
          toExemptStatus: 'text'
          toCity: 'text'
          toState: 'text'
          amount: 'bigint'
          nteeMajor: {type: 'text', defaultFn: -> '?'}
          nteeMinor: {type: 'text', defaultFn: -> '?'}
          relationship: 'text'
          purpose: 'text'
        primaryKey:
          partitionKey: ['fromEin']
          clusteringColumns: ['toId', 'nteeMajor', 'nteeMinor']
        materializedViews:
          irs_contributions_by_fromEin_and_ntee:
            primaryKey:
              partitionKey: ['fromEin']
              clusteringColumns: ['nteeMajor', 'nteeMinor', 'toId', 'year']
          irs_contributions_by_fromEin_and_year:
            primaryKey:
              partitionKey: ['fromEin']
              clusteringColumns: ['year', 'nteeMajor', 'nteeMinor', 'toId']
          irs_contributions_by_toId:
            primaryKey:
              partitionKey: ['toId']
              clusteringColumns: ['year', 'fromEin', 'nteeMajor', 'nteeMinor']
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

  getByAllByFromEin: (fromEin) =>
    cknex().select '*'
    .from 'irs_contributions_by_fromEin_and_toId'
    .where 'fromEin', '=', fromEin
    .run()
    .map @defaultOutput

module.exports = new IrsContributionModel()
