import _ from 'lodash';
import { Base, cknex, elasticsearch } from 'backend-shared';
import config from '../../config';

class IrsFund990Model extends Base {
  constructor(...args) {
    {
      // Hack: trick Babel/TypeScript into allowing this before super.
      if (false) { super(); }
      let thisFn = (() => { return this; }).toString();
      let thisName = thisFn.match(/return (?:_assertThisInitialized\()*(\w+)\)*;/)[1];
      eval(`${thisName} = this;`);
    }
    this.getAllByEin = this.getAllByEin.bind(this);
    super(...args);
  }

  getScyllaTables() {
    return [
      {
        name: 'irs_fund_990s_by_ein_and_year',
        keyspace: 'irs_990_api',
        fields: {
          ein: 'text',
          year: 'int',
          taxPeriod: 'text',
          objectId: 'text', // irs-defined, unique per filing
          returnVersion: 'text', // irs-defined
          submitDate: 'timestamp',
          lastIrsUpdate: 'timestamp',
          type: 'text', // 990, 990ez, 990pf
          xmlUrl: 'text',
          // pdfUrl: 'text' # TODO: https://www.irs.gov/charities-non-profits/tax-exempt-organization-search-bulk-data-downloads
          importVersion: {type: 'int', defaultFn() { return 0; }},

          name: 'text',
          city: 'text',
          state: 'text',
          website: 'text',
          mission: 'text',

          // contributionsAndGrants, interestOnSavings, dividendsFromSecurities,
          // netRental, netAssetSales, capitalGain, capitalGainShortTerm,
          // incomeModifications, grossSales, other, total
          revenue: {type: 'map', subType: 'text', subType2: 'bigint'},

          // officerSalaries, nonOfficerSalaries, employeeBenefits, legalFees,
          // accountingFees, otherProfessionalFees, interest, taxes, depreciation,
          // occupancy, travel, printing, other, totalOperations, contributionsAndGrants, total
          expenses: {type: 'map', subType: 'text', subType2: 'bigint'},

          netIncome: 'bigint',

          // boy, eoy
          assets: {type: 'map', subType: 'text', subType2: 'bigint'},

          // boy, eoy
          liabilities: {type: 'map', subType: 'text', subType2: 'bigint'},

          // boy, eoy
          netAssets: {type: 'map', subType: 'text', subType2: 'bigint'}
        },
        primaryKey: {
          partitionKey: ['ein'],
          clusteringColumns: ['year', 'objectId']
        }
          // TODO
          // withClusteringOrderBy: ['year', 'desc']
      }
    ];
  }

  getElasticSearchIndices() {
    return [
      {
        name: 'irs_fund_990s',
        mappings: {
          ein: {type: 'keyword'},
          year: {type: 'integer'},
          taxPeriod: {type: 'keyword'},
          objectId: {type: 'keyword'}, // irs-defined, unique per filing
          returnVersion: {type: 'keyword'}, // irs-defined
          submitDate: {type: 'date'},
          lastIrsUpdate: {type: 'date'},
          type: {type: 'keyword'}, // 990, 990ez, 990pf
          xmlUrl: {type: 'keyword'},
          pdfUrl: {type: 'keyword'},
          importVersion: {type: 'integer'},

          name: {type: 'text'},
          city: {type: 'text'},
          state: {type: 'text'},
          website: {type: 'text'},
          mission: {type: 'text'},
          exemptStatus: {type: 'text'},

          // TODO these aren't currently filled with values, need to rerun import (5/2020)
          revenue: {
            properties: {
              contributionsAndGrants: {type: 'long'},
              interestOnSavings: {type: 'long'},
              dividendsFromSecurities: {type: 'long'},
              netRental: {type: 'long'},
              netAssetSales: {type: 'long'},
              capitalGain: {type: 'long'},
              capitalGainShortTerm: {type: 'long'},
              incomeModifications: {type: 'long'},
              grossSales: {type: 'long'},
              other: {type: 'long'},
              total: {type: 'long'}
            }
          },

          expenses: {
            properties: {
              officerSalaries: {type: 'long'},
              nonOfficerSalaries: {type: 'long'},
              employeeBenefits: {type: 'long'},
              legalFees: {type: 'long'},
              accountingFees: {type: 'long'},
              otherProfessionalFees: {type: 'long'},
              interest: {type: 'long'},
              taxes: {type: 'long'},
              depreciation: {type: 'long'},
              occupancy: {type: 'long'},
              travel: {type: 'long'},
              printing: {type: 'long'},
              other: {type: 'long'},
              totalOperations: {type: 'long'},
              contributionsAndGrants: {type: 'long'},
              total: {type: 'long'}
            }
          },

          assets: {
            properties: {
              cashBoy: {type: 'long'},
              cashEoy: {type: 'long'},
              boy: {type: 'long'},
              eoy: {type: 'long'}
            }
          },
          liabilities: {
            properties: {
              boy: {type: 'long'},
              eoy: {type: 'long'}
            }
          },
          netAssets: {
            properties: {
              boy: {type: 'long'},
              eoy: {type: 'long'}
            }
          }
        }
      }
    ];
  }

  getAllByEin(ein) {
    return cknex().select('*')
    .from('irs_fund_990s_by_ein_and_year')
    .where('ein', '=', ein)
    // TODO: order with withClusteringOrderBy instead of this
    .orderBy('year', 'desc')
    .run()
    .map(this.defaultOutput);
  }
}

export default new IrsFund990Model();
