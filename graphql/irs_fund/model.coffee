_ = require 'lodash'
{Base, cknex, elasticsearch} = require 'backend-shared'

config = require '../../config'

class IrsFundModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_funds_by_ein'
        keyspace: 'irs_990_api'
        fields:
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

          lastYearStats: 'json'
          fundedNteeMajors: {type: 'json', defaultFn: -> []}
          fundedNtees: {type: 'json', defaultFn: -> []}
          fundedStates: {type: 'json', defaultFn: -> []}
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

          applicantInfo:
            properties:
              acceptsUnsolicitedRequests: {type: 'boolean'}
              address:
                properties:
                  street1: {type: 'keyword'}
                  street2: {type: 'keyword'}
                  postalCode: {type: 'keyword'}
                  city: {type: 'keyword'}
                  state: {type: 'keyword'}
                  countryCode: {type: 'keyword'}
              recipientName: {type: 'text'}
              requirements: {type: 'text'}
              deadlines: {type: 'text'}
              restrictions: {type: 'text'}
          directCharitableActivities:
            properties:
              lineItem:
                properties:
                  description: {type: 'text'}
                  expenses: {type: 'long'}
          programRelatedInvestments:
            properties:
              lineItem:
                properties:
                  description: {type: 'text'}
                  expenses: {type: 'long'}

          assets: {type: 'long'}
          netAssets: {type: 'long'}
          liabilities: {type: 'long'}

          lastYearStats:
            properties:
              year: {type: 'integer'}
              revenue: {type: 'long'}
              expenses: {type: 'long'}
              grants: {type: 'integer'}
              grantSum: {type: 'long'}
              grantMin: {type: 'integer'}
              grantMedian: {type: 'float'}
              grantMax: {type: 'integer'}

          fundedNteeMajors:
            type: 'nested'
            properties:
              count: {type: 'integer'}
              percent:
                type: 'scaled_float'
                scaling_factor: 100
              sum: {type: 'long'}
              sumPercent:
                type: 'scaled_float'
                scaling_factor: 100
          fundedNtees:
            type: 'nested'
            properties:
              count: {type: 'integer'}
              percent:
                type: 'scaled_float'
                scaling_factor: 100
              sum: {type: 'long'}
              sumPercent:
                type: 'scaled_float'
                scaling_factor: 100
          fundedStates:
            type: 'nested'
            properties:
              count: {type: 'integer'}
              percent:
                type: 'scaled_float'
                scaling_factor: 100
              sum: {type: 'long'}
              sumPercent:
                type: 'scaled_float'
                scaling_factor: 100

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
