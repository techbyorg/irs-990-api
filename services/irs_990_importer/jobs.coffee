_ = require 'lodash'
request = require 'request-promise'
exec = require('child_process').exec
Promise = require 'bluebird'
cheerio = require 'cheerio'

{getOrg990Json, getOrgJson, getOrgPersonsJson} = require './format_irs_990'
{getOrg990EZJson, getOrgEZPersonsJson} = require './format_irs_990ez'
{getFund990Json, getFundJson, getFundPersonsJson,
  getContributionsJson} = require './format_irs_990pf'
IrsContribution = require '../../graphql/irs_contribution/model'
IrsFund = require '../../graphql/irs_fund/model'
IrsFund990 = require '../../graphql/irs_fund_990/model'
IrsOrg = require '../../graphql/irs_org/model'
IrsOrg990 = require '../../graphql/irs_org_990/model'
IrsPerson = require '../../graphql/irs_person/model'

FIVE_MB = 5 * 1024 * 1024

processOrgFiling = (filing) ->
  existing990s = await IrsOrg990.getAllByEin filing.ReturnHeader.ein
  org990 = getOrg990Json filing
  orgPersons = getOrgPersonsJson filing
  {
    org990: org990
    persons: orgPersons
    org: getOrgJson org990, orgPersons, existing990s
  }

processOrgEZFiling = (filing) ->
  existing990s = await IrsOrg990.getAllByEin filing.ReturnHeader.ein
  org990 = getOrg990EZJson filing
  orgPersons = getOrgEZPersonsJson filing
  {
    org990: org990
    persons: orgPersons
    org: getOrgJson org990, orgPersons, existing990s
  }

processFundFiling = (filing) ->
  existing990s = await IrsFund990.getAllByEin filing.ReturnHeader.ein
  contributions = await getContributionsJson filing
  fund990 = getFund990Json filing
  fundPersons = getFundPersonsJson filing
  {
    fund: getFundJson fund990, fundPersons, existing990s
    persons: fundPersons
    fund990: fund990
    contributions: contributions
  }

getFilingJsonFromObjectId = (objectId) ->
  jsonStr = await new Promise (resolve, reject) ->
    exec "irsx #{objectId}", {maxBuffer: FIVE_MB}, (err, stdout, stderr) ->
      if err
        reject err
      resolve stdout or stderr

  filing = try
    JSON.parse jsonStr
  catch err
    # console.log jsonStr
    throw new Error 'json parse fail'

  formattedFiling = _.reduce filing, (obj, part) ->
    if part.schedule_name is 'ReturnHeader990x'
      obj.ReturnHeader = part.schedule_parts.returnheader990x_part_i
    else if part.schedule_name
      obj[part.schedule_name] = {
        parts: part.schedule_parts
        groups: part.groups
      }
    obj
  , {}
  formattedFiling.objectId = objectId

  return formattedFiling

module.exports = {
  upsertOrgs: ({orgs, i}) ->
    IrsOrg.batchUpsert orgs
    .then ->
      console.log 'upserted', i

  processOrgChunk: ({chunk}) ->
    Promise.map chunk, (org) ->
      getFilingJsonFromObjectId org.objectId
      .catch (err) ->
        console.log 'json parse fail'
        IrsOrg990.upsertByRow org, {isProcessed: true}
        .then ->
          throw 'skip'
      .then (filing) ->
        (if filing.IRS990
          processOrgFiling filing
        else
          processOrgEZFiling filing)
      .catch (err) ->
        console.log 'caught', err
        {}
    .then (filingResults) ->
      orgs = _.filter _.map filingResults, 'org'
      org990s = _.filter _.map filingResults, 'org990'
      persons = _.filter _.flatten _.map filingResults, 'persons'

      # console.log {orgs, org990s, persons}
      console.log 'orgs', orgs.length, 'org990s', org990s.length, 'persons', persons.length

      Promise.all _.filter [
        if orgs.length
          IrsOrg.batchUpsert orgs
        if org990s.length
          IrsOrg990.batchUpsert org990s, {ESRefresh: true} # so when we fetch isProcessed again, it's accurate
        if persons.length
          IrsPerson.batchUpsert persons
      ]

  processFundChunk: ({chunk}) ->
    Promise.map chunk, (fund) ->
      getFilingJsonFromObjectId fund.objectId
      .catch (err) ->
        console.log 'json parse fail'
        IrsFund990.upsertByRow fund, {isProcessed: true}
        .then ->
          throw 'skip'
      .then (filing) ->
        processFundFiling filing
      .catch (err) ->
        console.log 'caught', err
        {}
    .then (filingResults) ->
      funds = _.filter _.map filingResults, 'fund'
      fund990s = _.filter _.map filingResults, 'fund990'
      persons = _.filter _.flatten _.map filingResults, 'persons'
      contributions = _.filter _.flatten _.map filingResults, 'contributions'

      # console.log {funds, fund990s, persons}
      console.log 'funds', funds.length, 'fund990s', fund990s.length, 'persons', persons.length, 'contributions', contributions.length
      # console.log _.map contributions, (c) -> _.pick c, ['toId', 'toName', 'nteeMajor', 'nteeMinor']

      Promise.all _.filter [
        if funds.length
          IrsFund.batchUpsert funds
        if fund990s.length
          IrsFund990.batchUpsert fund990s, {ESRefresh: true} # so when we fetch isProcessed again, it's accurate
        if persons.length
          IrsPerson.batchUpsert persons
        if contributions.length
          IrsContribution.batchUpsert contributions
      ]

  parseWebsite: ({ein, counter}) ->
    irsOrg = await IrsOrg.getByEin ein

    request {
      uri: irsOrg.website
      headers:
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36'
    }
    .then (html) ->
      $ = cheerio.load html
      text = $.text().toLowerCase()
      text = text.replace /\s+/g, ' '
      console.log 'upsert', text.length
      IrsOrg.upsertByRow irsOrg, {
        websiteText: text.substr(0, 10000)
      }
    .catch (err) ->
      console.log 'website err', irsOrg.website
    .then ->
      console.log counter
}
