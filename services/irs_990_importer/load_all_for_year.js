_ = require 'lodash'
request = require 'request-promise'
Promise = require 'bluebird'

IrsFund = require '../../graphql/irs_fund/model'
IrsFund990 = require '../../graphql/irs_fund_990/model'
IrsOrg = require '../../graphql/irs_org/model'
IrsOrg990 = require '../../graphql/irs_org_990/model'
config = require '../../config'

getIndexJson = (year) ->
  indexUrl = "#{config.IRSX_XML_HTTP_BASE}/index_#{year}.json"
  console.log 'get', indexUrl
  request indexUrl

module.exports = {
  loadAllForYear: (year) ->
    if year
      index = JSON.parse await getIndexJson year
    else
      index = require('../../data/sample_index.json')
      year = 2016

    console.log 'got index'
    console.log 'keys', _.keys(index)
    filings = index["Filings#{year}"]
    console.log filings.length
    chunks = _.chunk filings, 500
    Promise.map chunks, (chunk, i) ->
      funds = _.filter chunk, {FormType: '990PF'}
      orgs = _.filter chunk, ({FormType}) -> FormType isnt '990PF'
      console.log i * 100
      console.log 'funds', funds.length, 'orgs', orgs.length
      Promise.all _.filter [
        if funds.length
          IrsFund.batchUpsert _.map funds, (filing) ->
            {
              ein: filing.EIN
              name: filing.OrganizationName
            }
        if funds.length
          IrsFund990.batchUpsert _.map funds, (filing) ->
            {
              ein: filing.EIN
              year: filing.TaxPeriod.substr(0, 4)
              taxPeriod: filing.TaxPeriod
              objectId: filing.ObjectId
              submitDate: new Date filing.SubmittedOn
              lastIrsUpdate: new Date filing.LastUpdated
              type: filing.FormType
              xmlUrl: filing.URL
            }

        if orgs.length
          IrsOrg.batchUpsert _.map orgs, (filing) ->
            {
              ein: filing.EIN
              name: filing.OrganizationName
            }
        if orgs.length
          IrsOrg990.batchUpsert _.map orgs, (filing) ->
            {
              ein: filing.EIN
              year: filing.TaxPeriod.substr(0, 4)
              taxPeriod: filing.TaxPeriod
              objectId: filing.ObjectId
              submitDate: new Date filing.SubmittedOn
              lastIrsUpdate: new Date filing.LastUpdated
              type: filing.FormType
              xmlUrl: filing.URL
          }
      ]
    , {concurrency: 10}
    .then ->
      console.log 'done'
}
