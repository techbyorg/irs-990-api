_ = require 'lodash'

Base = require '../base_model'
CacheService = require '../../services/cache'
cknex = require '../../services/cknex'
elasticsearch = require '../../services/elasticsearch'
config = require '../../config'

class IrsFundModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_funds_by_ein'
        keyspace: 'monocle'
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

          websiteText: {type: 'text'} # TODO: rm or move to diff table
          lastContributions: {type: 'long'}

      }
    ]

  getByEin: (ein) =>
    cknex().select '*'
    .from 'irs_funds_by_ein'
    .where 'ein', '=', ein
    .run {isSingle: true}
    .then @defaultOutput

module.exports = new IrsFundModel()
