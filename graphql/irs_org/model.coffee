_ = require 'lodash'

Base = require '../base_model'
CacheService = require '../../services/cache'
FormatService = require '../../services/format'
cknex = require '../../services/cknex'
elasticsearch = require '../../services/elasticsearch'
config = require '../../config'

class IrsOrgModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_orgs_by_ein'
        keyspace: 'monocle'
        fields:
          id: 'timeuuid'
          ein: 'text'
          name: 'text'
          city: 'text'
          state: 'text' # 2 letter code
          nteecc: 'text' # https://nccs.urban.org/project/national-taxonomy-exempt-entities-ntee-codes

          website: 'text'
          mission: 'text'
          exemptStatus: 'text'

          assets: 'bigint'
          liabilities: 'bigint'
          lastRevenue: 'bigint'
          lastExpenses: 'bigint'
          topSalary: 'json'
        primaryKey:
          partitionKey: ['ein']
      }
    ]

  getElasticSearchIndices: ->
    [
      {
        name: 'irs_orgs'
        mappings:
          ein: {type: 'text'}
          name: {type: 'search_as_you_type'}
          city: {type: 'text'}
          state: {type: 'text'}
          nteecc: {type: 'text'}

          website: {type: 'text'}
          mission: {type: 'text'}
          exemptStatus: {type: 'text'}

          assets: {type: 'long'}
          liabilities: {type: 'long'}
          lastRevenue: {type: 'long'}
          lastExpenses: {type: 'long'}

          topSalary: {type: 'object'}

          websiteText: {type: 'text'} # TODO: move to diff table?
      }
    ]

  getByEin: (ein) =>
    cknex().select '*'
    .from 'irs_orgs_by_ein'
    .where 'ein', '=', ein
    .run {isSingle: true}
    .then @defaultOutput

  defaultESInput: (row) =>
    _.defaults {id: row.ein}, row

  defaultOutput: (row) ->
    super row
    if row
      row.city = FormatService.fixAllCaps row.city
      row.name = FormatService.fixAllCaps row.name
    row

module.exports = new IrsOrgModel()
