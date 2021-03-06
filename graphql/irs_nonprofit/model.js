import { Base, cknex } from 'backend-shared'

// TODO: rename tables from org -> nonprofit

class IrsNonprofitModel extends Base {
  getScyllaTables () {
    return [
      {
        name: 'irs_orgs_by_ein',
        keyspace: 'irs_990_api',
        fields: {
          ein: 'text',
          name: 'text',
          city: 'text',
          state: 'text', // 2 letter code
          nteecc: 'text', // https://nccs.urban.org/project/national-taxonomy-exempt-entities-ntee-codes

          website: 'text',
          mission: 'text',
          exemptStatus: 'text',

          assets: 'bigint',
          netAssets: 'bigint',
          liabilities: 'bigint',
          employeeCount: 'int',
          volunteerCount: 'int',

          lastYearStats: 'json'
        },
        primaryKey: {
          partitionKey: ['ein']
        }
      }
    ]
  }

  getElasticSearchIndices () {
    return [
      {
        name: 'irs_orgs',
        _source: {
          excludes: ['websiteText'] // https://ambar.cloud/blog/2017/01/02/es-large-text/
        },
        mappings: {
          ein: { type: 'text' },
          name: { type: 'search_as_you_type' },
          city: { type: 'text' },
          state: { type: 'text' },
          nteecc: { type: 'text' },

          website: { type: 'text' },
          mission: { type: 'text' },
          exemptStatus: { type: 'text' },

          assets: { type: 'long' },
          netAssets: { type: 'long' },
          liabilities: { type: 'long' },
          employeeCount: { type: 'integer' },
          volunteerCount: { type: 'integer' },

          lastYearStats: {
            properties: {
              year: { type: 'integer' },
              revenue: { type: 'long' },
              expenses: { type: 'long' },
              topSalary: {
                properties: {
                  name: { type: 'text' },
                  title: { type: 'text' },
                  compensation: { type: 'integer' }
                }
              }
            }
          },

          // https://ambar.cloud/blog/2017/01/02/es-large-text/
          websiteText: { type: 'text', store: true } // store separately
        }
      }
    ]
  }

  getByEin (ein) {
    return cknex().select('*')
      .from('irs_orgs_by_ein')
      .where('ein', '=', ein)
      .run({ isSingle: true })
      .then(this.defaultOutput)
  }

  getAllByEins (eins) {
    return cknex().select('*')
      .from('irs_orgs_by_ein')
      .where('ein', 'in', eins)
      .run()
      .map(this.defaultOutput)
  }
}

export default new IrsNonprofitModel()
