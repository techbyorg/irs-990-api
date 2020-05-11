_ = require 'lodash'
request = require 'request-promise'
Promise = require 'bluebird'

IrsFund = require '../../graphql/irs_fund/model'
IrsFund990 = require '../../graphql/irs_fund_990/model'
IrsOrg = require '../../graphql/irs_org/model'
IrsOrg990 = require '../../graphql/irs_org_990/model'

module.exports = {
  getIndexJson: (year) ->
    indexUrl = "https://s3.amazonaws.com/irs-form-990/index_#{year}.json"
    request indexUrl

  loadAllForYear: (year) =>
    if year
      index = JSON.parse await @getIndexJson year
    else
      index = require('../../data/sample_index.json')
      year = 2016

    console.log 'got index'
    console.log 'keys', _.keys(index)
    filings = index["Filings#{year}"]
    console.log filings.length
    chunks = _.chunk filings, 100
    Promise.map chunks, (chunk, i) ->
      console.log i * 100
      funds = _.filter chunk, {FormType: '990PF'}
      console.log 'funds', funds.length
      orgs = _.filter chunk, ({FormType}) -> FormType isnt '990PF'
      console.log 'orgs', orgs.length
      Promise.all _.filter [
        if funds.length
          console.log 'batch', _.map funds, (filing) ->
            {
              ein: filing.EIN
              name: filing.OrganizationName
            }
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
              objectId: filing.ObjectId
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
              objectId: filing.ObjectId
              type: filing.FormType
              xmlUrl: filing.URL
          }
      ]
    , {concurrency: 10}
}
