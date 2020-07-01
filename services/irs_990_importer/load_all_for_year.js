import _ from 'lodash'
import fs from 'fs'
import request from 'request-promise'
import Promise from 'bluebird'

import IrsFund from '../../graphql/irs_fund/model.js'
import IrsFund990 from '../../graphql/irs_fund_990/model.js'
import IrsNonprofit from '../../graphql/irs_nonprofit/model.js'
import IrsNonprofit990 from '../../graphql/irs_nonprofit_990/model.js'
import config from '../../config.js'

function getIndexJson (year) {
  const indexUrl = `${config.IRSX_XML_HTTP_BASE}/index_${year}.json`
  console.log('get', indexUrl)
  return request(indexUrl)
}

export async function loadAllForYear (year) {
  let index
  if (year) {
    index = JSON.parse(await getIndexJson(year))
  } else {
    index = JSON.parse(fs.readFileSync('./data/sample_index.json', 'utf8'))
    year = 2016
  }

  console.log('got index')
  console.log('keys', _.keys(index))
  const filings = index[`Filings${year}`]
  console.log(filings.length)
  const chunks = _.chunk(filings, 500)
  return Promise.map(chunks, function (chunk, i) {
    const funds = _.filter(chunk, { FormType: '990PF' })
    const nonprofits = _.filter(chunk, ({ FormType }) => FormType !== '990PF')
    console.log(i * 100)
    console.log('funds', funds.length, 'nonprofits', nonprofits.length)
    return Promise.all(_.filter([
      funds.length &&
        IrsFund.batchUpsert(_.map(funds, filing => ({
          ein: filing.EIN,
          name: filing.OrganizationName
        }))),
      funds.length &&
        IrsFund990.batchUpsert(_.map(funds, filing => ({
          ein: filing.EIN,
          year: filing.TaxPeriod.substr(0, 4),
          taxPeriod: filing.TaxPeriod,
          objectId: filing.ObjectId,
          submitDate: new Date(filing.SubmittedOn),
          lastIrsUpdate: new Date(filing.LastUpdated),
          type: filing.FormType,
          xmlUrl: filing.URL
        }))),

      nonprofits.length &&
        IrsNonprofit.batchUpsert(_.map(nonprofits, filing => ({
          ein: filing.EIN,
          name: filing.OrganizationName
        }))),
      nonprofits.length &&
        IrsNonprofit990.batchUpsert(_.map(nonprofits, filing => ({
          ein: filing.EIN,
          year: filing.TaxPeriod.substr(0, 4),
          taxPeriod: filing.TaxPeriod,
          objectId: filing.ObjectId,
          submitDate: new Date(filing.SubmittedOn),
          lastIrsUpdate: new Date(filing.LastUpdated),
          type: filing.FormType,
          xmlUrl: filing.URL
        })))
    ]))
  }
  , { concurrency: 10 })
    .then(() => console.log('done'))
}
