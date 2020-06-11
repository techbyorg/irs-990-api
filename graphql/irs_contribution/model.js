/* eslint-disable
    constructor-super,
    no-constant-condition,
    no-eval,
    no-return-assign,
    no-this-before-super,
    no-unused-vars,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
import _ from 'lodash'
import { Base, cknex, elasticsearch } from 'backend-shared'
import config from '../../config'

// example 990pf: https://s3.amazonaws.com/irs-form-990/201533209349101373_public.xml

class IrsContributionModel extends Base {
  constructor (...args) {
    {
      // Hack: trick Babel/TypeScript into allowing this before super.
      if (false) { super() }
      const thisFn = (() => { return this }).toString()
      const thisName = thisFn.match(/return (?:_assertThisInitialized\()*(\w+)\)*;/)[1]
      eval(`${thisName} = this;`)
    }
    this.getAllByFromEin = this.getAllByFromEin.bind(this)
    this.getAllByToId = this.getAllByToId.bind(this)
    super(...args)
  }

  getScyllaTables () {
    return [
      {
        name: 'irs_contributions_by_fromEin_and_toId',
        keyspace: 'irs_990_api',
        fields: {
          year: 'int',
          fromEin: 'text',
          toId: 'text', // ein or name if no ein
          toName: 'text',
          hash: 'text', // unique identifier if multiple to same toId in a year
          // ^^ md5 year, toName, toCity, toState, purpose, amount
          toExemptStatus: 'text',
          toCity: 'text',
          toState: 'text',
          amount: 'bigint',
          type: 'text', // org | person
          nteeMajor: { type: 'text', defaultFn () { return '?' } },
          nteeMinor: { type: 'text', defaultFn () { return '?' } },
          relationship: 'text',
          purpose: 'text'
        },
        primaryKey: {
          partitionKey: ['fromEin'],
          clusteringColumns: ['toId', 'year', 'hash']
        },
        materializedViews: {
          irs_contributions_by_fromEin_and_ntee: {
            primaryKey: {
              partitionKey: ['fromEin'],
              clusteringColumns: ['nteeMajor', 'toId', 'year', 'hash']
            }
          },
          irs_contributions_by_fromEin_and_year: {
            primaryKey: {
              partitionKey: ['fromEin'],
              clusteringColumns: ['year', 'toId', 'hash']
            },
            withClusteringOrderBy: [['year', 'desc'], ['toId', 'asc']]
          },
          irs_contributions_by_toId: {
            primaryKey: {
              partitionKey: ['toId'],
              clusteringColumns: ['year', 'fromEin', 'hash']
            },
            withClusteringOrderBy: ['year', 'desc']
          }
        }
      }
    ]
  }

  getElasticSearchIndices () {
    return [
      {
        name: 'irs_contributions',
        mappings: {
          fromEin: { type: 'keyword' },
          year: { type: 'integer' },
          toId: { type: 'keyword' }, // ein or name if no ein
          toName: { type: 'text' },
          hash: { type: 'text' },
          toExemptStatus: { type: 'keyword' },
          toCity: { type: 'keyword' },
          toState: { type: 'keyword' },
          amount: { type: 'long' },
          nteeMajor: { type: 'keyword' },
          nteeMinor: { type: 'keyword' },
          relationship: { type: 'text' },
          purpose: { type: 'text' }
        }
      }
    ]
  }

  getAllByFromEin (fromEin, { limit } = {}) {
    const q = cknex().select('*')
      .from('irs_contributions_by_fromEin_and_year')
      .where('fromEin', '=', fromEin)
    if (limit) {
      q.limit(limit)
    }
    return q.run()
      .map(this.defaultOutput)
  }

  getAllByToId (toId, { limit } = {}) {
    let q
    return q = cknex().select('*')
      .from('irs_contributions_by_toId')
      .where('toId', '=', toId)
      .run()
      .then(function (irsContributions) {
        irsContributions.reverse()
        if (limit) {
          return _.take(irsContributions, limit)
        } else {
          return irsContributions
        }
      }).map(this.defaultOutput)
  }

  getAllFromEinsFromToEins (toIds) {
    let q
    return q = cknex().select('fromEin', 'toId', 'amount')
      .from('irs_contributions_by_toId')
      .where('toId', 'IN', toIds)
      .run()
  }
}

export default new IrsContributionModel()
