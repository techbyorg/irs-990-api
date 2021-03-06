import { Base, cknex } from 'backend-shared'

class IrsNonprofit990Model extends Base {
  getScyllaTables () {
    return [
      {
        name: 'irs_org_990s_by_ein_and_year',
        keyspace: 'irs_990_api',
        fields: {
          ein: 'text',
          year: 'int',
          objectId: 'text', // irs-defined, unique per filing
          taxPeriod: 'text', // irs-defined
          returnVersion: 'text', // irs-defined
          submitDate: 'timestamp',
          lastIrsUpdate: 'timestamp',
          type: 'text', // 990, 990ez, 990pf
          xmlUrl: 'text',
          // pdfUrl: 'text' # TODO: https://www.irs.gov/charities-non-profits/tax-exempt-organization-search-bulk-data-downloads
          importVersion: { type: 'int', defaultFn () { return 0 } },

          name: 'text',
          city: 'text',
          state: 'text',
          website: 'text',
          mission: 'text',
          exemptStatus: 'text',

          paidBenefitsToMembers: 'bigint',
          votingMemberCount: 'int',
          independentVotingMemberCount: 'int',
          employeeCount: 'int',
          volunteerCount: 'int',

          // investments, grants, ubi, netUbi, contributionsAndGrants, programService, other, total
          revenue: { type: 'map', subType: 'text', subType2: 'bigint' },

          // salaries, professionalFundraising, fundraising, other, total
          expenses: { type: 'map', subType: 'text', subType2: 'bigint' },

          // boy, eoy
          assets: { type: 'map', subType: 'text', subType2: 'bigint' },

          // boy, eoy
          liabilities: { type: 'map', subType: 'text', subType2: 'bigint' },

          // boy, eoy
          netAssets: { type: 'map', subType: 'text', subType2: 'bigint' }
        },
        primaryKey: {
          partitionKey: ['ein'],
          clusteringColumns: ['year', 'objectId']
        }
        // TODO
        // withClusteringOrderBy: ['year', 'desc']
      }
    ]
  }

  getElasticSearchIndices () {
    return [
      {
        name: 'irs_org_990s',
        mappings: {
          ein: { type: 'keyword' },
          year: { type: 'integer' },
          taxPeriod: { type: 'keyword' },
          objectId: { type: 'keyword' }, // irs-defined, unique per filing
          returnVersion: { type: 'keyword' }, // irs-defined
          submitDate: { type: 'date' },
          lastIrsUpdate: { type: 'date' },
          type: { type: 'keyword' }, // 990, 990ez, 990pf
          xmlUrl: { type: 'keyword' },
          pdfUrl: { type: 'keyword' },
          importVersion: { type: 'integer' },

          name: { type: 'text' },
          city: { type: 'text' },
          state: { type: 'text' },
          website: { type: 'text' },
          mission: { type: 'text' },
          exemptStatus: { type: 'text' },

          paidBenefitsToMembers: { type: 'long' },
          votingMemberCount: { type: 'integer' },
          independentVotingMemberCount: { type: 'integer' },
          employeeCount: { type: 'integer' },
          volunteerCount: { type: 'integer' },

          // TODO specify properties & reindex
          revenue: { type: 'object' },
          expenses: { type: 'object' },
          assets: { type: 'object' },
          liabilities: { type: 'object' },
          netAssets: { type: 'object' }
        }
      }
    ]
  }

  getAllByEin (ein) {
    return cknex().select('*')
      .from('irs_org_990s_by_ein_and_year')
      .where('ein', '=', ein)
      // TODO: order with withClusteringOrderBy instead of this
      .orderBy('year', 'desc')
      .run()
      .map(this.defaultOutput)
  }
}

export default new IrsNonprofit990Model()
