_ = require 'lodash'
{Base, cknex, elasticsearch} = require 'phil-helpers'

config = require '../../config'

class IrsFund990Model extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_fund_990s_by_ein_and_year'
        keyspace: 'monocle'
        fields:
          id: 'timeuuid'
          ein: 'text'
          year: 'int'
          objectId: 'text' # irs-defined, unique per filing
          type: 'text' # 990, 990ez, 990pf
          xmlUrl: 'text'
          pdfUrl: 'text'
          importVersion: {type: 'int', defaultFn: -> 0}

          name: 'text'
          city: 'text'
          state: 'text'
          website: 'text'
          mission: 'text'

        primaryKey:
          partitionKey: ['ein']
          clusteringColumns: ['year', 'objectId']
      }
    ]

  getElasticSearchIndices: ->
    [
      {
        name: 'irs_fund_990s'
        mappings:
          ein: {type: 'keyword'}
          year: {type: 'integer'}
          objectId: {type: 'keyword'} # irs-defined, unique per filing
          type: {type: 'keyword'} # 990, 990ez, 990pf
          xmlUrl: {type: 'keyword'}
          pdfUrl: {type: 'keyword'}
          importVersion: {type: 'integer'}

          name: {type: 'text'}
          city: {type: 'text'}
          state: {type: 'text'}
          website: {type: 'text'}
          mission: {type: 'text'}
          exemptStatus: {type: 'text'}

      }
    ]

  getAllByEin: (ein) =>
    cknex().select '*'
    .from 'irs_fund_990s_by_ein_and_year'
    .where 'ein', '=', ein
    .run()
    .map @defaultOutput

module.exports = new IrsFund990Model()
