_ = require 'lodash'
{Base, cknex, elasticsearch} = require 'phil-helpers'

config = require '../../config'

class IrsFund990Model extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_fund_990s_by_ein_and_year'
        keyspace: 'irs_990_api'
        fields:
          ein: 'text'
          year: 'int'
          taxPeriod: 'text'
          objectId: 'text' # irs-defined, unique per filing
          filingVersion: 'text' # irs-defined
          submitDate: 'timestamp'
          lastIrsUpdate: 'timestamp'
          type: 'text' # 990, 990ez, 990pf
          xmlUrl: 'text'
          # pdfUrl: 'text' # TODO: https://www.irs.gov/charities-non-profits/tax-exempt-organization-search-bulk-data-downloads
          importVersion: {type: 'int', defaultFn: -> 0}

          name: 'text'
          city: 'text'
          state: 'text'
          website: 'text'
          mission: 'text'

          # contributionsAndGrants, interestOnSavings, dividendsFromSecurities,
          # netRental, netAssetSales, capitalGain, capitalGainShortTerm,
          # incomeModifications, grossSales, other, total
          revenue: {type: 'map', subType: 'text', subType2: 'bigint'}

          # officerSalaries, nonOfficerSalaries, employeeBenefits, legalFees,
          # accountingFees, otherProfessionalFees, interest, taxes, depreciation,
          # occupancy, travel, printing, other, totalOperations, contributionsAndGrants, total
          expenses: {type: 'map', subType: 'text', subType2: 'bigint'}

          netIncome: 'bigint'

          # boy, eoy
          assets: {type: 'map', subType: 'text', subType2: 'bigint'}

          # boy, eoy
          liabilities: {type: 'map', subType: 'text', subType2: 'bigint'}

          # boy, eoy
          netAssets: {type: 'map', subType: 'text', subType2: 'bigint'}
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
          taxPeriod: {type: 'keyword'}
          objectId: {type: 'keyword'} # irs-defined, unique per filing
          filingVersion: {type: 'keyword'} # irs-defined
          submitDate: {type: 'date'}
          lastIrsUpdate: {type: 'date'}
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
