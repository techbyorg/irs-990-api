_ = require 'lodash'

Base = require '../base_model'
CacheService = require '../../services/cache'
cknex = require '../../services/cknex'
elasticsearch = require '../../services/elasticsearch'
config = require '../../config'

class IrsOrg990Model extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_org_990s_by_ein_and_year'
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
          exemptStatus: 'text'

          # benefitsPaidToMembers: 'int'
          # some rows are still on benefitsPaidToMembers, which is int
          # had to switch to bigint for some that pay billions?
          paidBenefitsToMembers: 'bigint'
          votingMemberCount: 'int'
          independentVotingMemberCount: 'int'
          employeeCount: 'int'
          volunteerCount: 'int'

          revenue: {type: 'map', subType: 'text', subType2: 'bigint'}
          expenses: {type: 'map', subType: 'text', subType2: 'bigint'}
          assets: {type: 'map', subType: 'text', subType2: 'bigint'}
          liabilities: {type: 'map', subType: 'text', subType2: 'bigint'}
          netAssets: {type: 'map', subType: 'text', subType2: 'bigint'}
        primaryKey:
          partitionKey: ['ein']
          clusteringColumns: ['year', 'objectId']
      }
    ]

  getElasticSearchIndices: ->
    [
      {
        name: 'irs_org_990s'
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

          # benefitsPaidToMembers: {type: 'int'}
          paidBenefitsToMembers: {type: 'long'}
          votingMemberCount: {type: 'integer'}
          independentVotingMemberCount: {type: 'integer'}
          employeeCount: {type: 'integer'}
          volunteerCount: {type: 'integer'}

          revenue: {type: 'object'}
          expenses: {type: 'object'}
          assets: {type: 'object'}
          liabilities: {type: 'object'}
          netAssets: {type: 'object'}
      }
    ]


  getAllByEin: (ein) =>
    cknex().select '*'
    .from 'irs_org_990s_by_ein_and_year'
    .where 'ein', '=', ein
    .run()
    .map @defaultOutput


module.exports = new IrsOrg990Model()
