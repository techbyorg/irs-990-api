_ = require 'lodash'
{Base, cknex, elasticsearch} = require 'phil-helpers'

config = require '../../config'

class IrsFundModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_funds_by_ein'
        keyspace: 'irs_990_api'
        fields:
          id: 'timeuuid'
          ein: 'text'
          name: 'text'
          city: 'text'
          state: 'text' # 2 letter code
          nteecc: 'text' # https://nccs.urban.fund/project/national-taxonomy-exempt-entities-ntee-codes

          website: 'text'
          mission: 'text'
          exemptStatus: 'text'

          applicantInfo: 'json'
          directCharitableActivities: 'json'
          programRelatedInvestments: 'json'

          assets: 'bigint'
          netAssets: 'bigint'
          liabilities: 'bigint'

          lastRevenue: 'bigint'
          lastExpenses: 'bigint'
          lastContributionsAndGrants: 'bigint'
        primaryKey:
          partitionKey: ['ein']
      }
    ]

  getElasticSearchIndices: ->
    [
      {
        name: 'irs_funds'
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
          lastRevenue: {type: 'long'}
          lastExpenses: {type: 'long'}
          lastContributionsAndGrants: {type: 'long'}

          applicantInfo: {type: 'object'}
          directCharitableActivities: {type: 'object'}
          programRelatedInvestments: {type: 'object'}

          websiteText: {type: 'text'} # TODO: move to diff table?
      }
    ]

  getByEin: (ein) =>
    cknex().select '*'
    .from 'irs_funds_by_ein'
    .where 'ein', '=', ein
    .run {isSingle: true}
    .then @defaultOutput

module.exports = new IrsFundModel()
