// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
import _ from 'lodash'
import request from 'request-promise'
import Promise from 'bluebird'
import IrsFund from '../../graphql/irs_fund/model'
import IrsFund990 from '../../graphql/irs_fund_990/model'
import IrsOrg from '../../graphql/irs_org/model'
import IrsOrg990 from '../../graphql/irs_org_990/model'
import config from '../../config'

function getIndexJson (year) {
  const indexUrl = `${config.IRSX_XML_HTTP_BASE}/index_${year}.json`
  console.log('get', indexUrl)
  return request(indexUrl)
}

export default {
  async loadAllForYear (year) {
    let index
    if (year) {
      index = JSON.parse(await getIndexJson(year))
    } else {
      index = require('../../data/sample_index.json')
      year = 2016
    }

    console.log('got index')
    console.log('keys', _.keys(index))
    const filings = index[`Filings${year}`]
    console.log(filings.length)
    const chunks = _.chunk(filings, 500)
    return Promise.map(chunks, function (chunk, i) {
      const funds = _.filter(chunk, { FormType: '990PF' })
      const orgs = _.filter(chunk, ({ FormType }) => FormType !== '990PF')
      console.log(i * 100)
      console.log('funds', funds.length, 'orgs', orgs.length)
      return Promise.all(_.filter([
        funds.length
          ? IrsFund.batchUpsert(_.map(funds, filing => ({
            ein: filing.EIN,
            name: filing.OrganizationName
          }))) : undefined,
        funds.length
          ? IrsFund990.batchUpsert(_.map(funds, filing => ({
            ein: filing.EIN,
            year: filing.TaxPeriod.substr(0, 4),
            taxPeriod: filing.TaxPeriod,
            objectId: filing.ObjectId,
            submitDate: new Date(filing.SubmittedOn),
            lastIrsUpdate: new Date(filing.LastUpdated),
            type: filing.FormType,
            xmlUrl: filing.URL
          }))) : undefined,

        orgs.length
          ? IrsOrg.batchUpsert(_.map(orgs, filing => ({
            ein: filing.EIN,
            name: filing.OrganizationName
          }))) : undefined,
        orgs.length
          ? IrsOrg990.batchUpsert(_.map(orgs, filing => ({
            ein: filing.EIN,
            year: filing.TaxPeriod.substr(0, 4),
            taxPeriod: filing.TaxPeriod,
            objectId: filing.ObjectId,
            submitDate: new Date(filing.SubmittedOn),
            lastIrsUpdate: new Date(filing.LastUpdated),
            type: filing.FormType,
            xmlUrl: filing.URL
          }))) : undefined
      ]))
    }
    , { concurrency: 10 })
      .then(() => console.log('done'))
  }
}
