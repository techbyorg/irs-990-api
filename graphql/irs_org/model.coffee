_ = require 'lodash'
{Base, cknex, elasticsearch, Format} = require 'phil-helpers'

config = require '../../config'

class IrsOrgModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_orgs_by_ein'
        keyspace: 'irs_990_api'
        fields:
          ein: 'text'
          name: 'text'
          city: 'text'
          state: 'text' # 2 letter code
          nteecc: 'text' # https://nccs.urban.org/project/national-taxonomy-exempt-entities-ntee-codes

          website: 'text'
          mission: 'text'
          exemptStatus: 'text'

          assets: 'bigint'
          netAssets: 'bigint'
          liabilities: 'bigint'
          employeeCount: 'int'
          volunteerCount: 'int'

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
          netAssets: {type: 'long'}
          liabilities: {type: 'long'}
          employeeCount: {type: 'integer'}
          volunteerCount: {type: 'integer'}

          lastRevenue: {type: 'long'}
          lastExpenses: {type: 'long'}

          # TODO: specify properties & reindex
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

module.exports = new IrsOrgModel()
