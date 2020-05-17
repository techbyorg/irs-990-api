_ = require 'lodash'
request = require 'request-promise'
exec = require('child_process').exec
spawn = require('child_process').spawn
Promise = require 'bluebird'
cheerio = require 'cheerio'
request = require 'request-promise'
DataLoader = require 'dataloader'
fs = require 'fs-extra'

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
config = require '../../config'

irsxEnv = _.defaults {
  IRSX_XML_HTTP_BASE: config.IRSX_XML_HTTP_BASE
  IRSX_CACHE_DIRECTORY: config.IRSX_CACHE_DIRECTORY
}, _.clone(process.env)

processOrgFiling = (filing) ->
  existing990s = await IrsOrg990.getAllByEin filing.ReturnHeader.ein
  org990 = getOrg990Json filing
  orgPersons = getOrgPersonsJson filing
  {
    model: getOrgJson org990, orgPersons, existing990s
    model990: org990
    persons: orgPersons
  }

processOrgEZFiling = (filing) ->
  existing990s = await IrsOrg990.getAllByEin filing.ReturnHeader.ein
  org990 = getOrg990EZJson filing
  orgPersons = getOrgEZPersonsJson filing
  {
    model: getOrgJson org990, orgPersons, existing990s
    model990: org990
    persons: orgPersons
  }

processFundFiling = (filing) ->
  existing990s = await IrsFund990.getAllByEin filing.ReturnHeader.ein
  fund990 = getFund990Json filing
  fundPersons = getFundPersonsJson filing
  contributions = await getContributionsJson filing
  {
    model: getFundJson fund990, fundPersons, contributions, existing990s
    model990: fund990
    persons: fundPersons
    contributions: contributions
  }

convertFiling = (filing) ->
  _.reduce filing, (obj, part) ->
    if part.schedule_name is 'ReturnHeader990x'
      obj.ReturnHeader = part.schedule_parts.returnheader990x_part_i
    else if part.schedule_name
      obj[part.schedule_name] = {
        parts: part.schedule_parts
        groups: part.groups
      }
    obj
  , {}

add990Versions = (chunk) ->
  Promise.map chunk, (model990) ->
    fileName = "#{model990.objectId}_public.xml"
    try
      xml = await request "#{config.IRSX_XML_HTTP_BASE}/#{fileName}"
      try
        # since we've already downloaded, store in cache for irsx to use...
        await fs.outputFile "#{config.IRSX_CACHE_DIRECTORY}/XML/#{fileName}", xml
      catch err
        console.log err
      returnVersion = xml.match(/returnVersion="(.*?)"/i)?[1]
    catch err
      returnVersion = null

    _.defaults {returnVersion}, model990

getFilingJsonFromObjectIds = (objectIds) ->
  jsonStr = await new Promise (resolve, reject) ->
    child = spawn "irsx", objectIds, {
      env: irsxEnv
    }
    str = ''
    child.stdout.on 'data', (chunk) ->
      str += chunk
    child.on 'error', (error) ->
      console.log 'err', error
      reject error
    child.on 'close', (code, signal) ->
      if code isnt 0
        console.log 'code not 0', code, signal
        reject 'failure'
      resolve "[#{str.replace /\]\[/g, '],['}]"

  filings = try
    JSON.parse jsonStr
  catch err
    throw new Error 'json parse fail'

  _.map filings, (filing, i) ->
    formattedFiling = convertFiling filing
    _.defaults {objectId: objectIds[i]}, formattedFiling

formattedFilingsFromObjectIdsLoaderFn = (objectIds) ->
  try
    getFilingJsonFromObjectIds objectIds
  catch err
    # if irsx fails on bulk, do 1 by 1 so we at least get the working ones
    console.log 'doing 1 by 1', err
    Promise.map objectIds, (objectId) ->
      getFilingJsonFromObjectIds [objectId]
      .then ([filingJson]) -> filingJson
      .catch (err) ->
        console.log "json parse fail: #{objectId}"
        await Model990.upsertByRow model990, {
          importVersion: config.CURRENT_IMPORT_VERSION
        }
        null

processChunk = ({chunk, Model990, processFilingFn, processResultsFn}) ->
  start = Date.now()
  modifiedModel990s = await add990Versions chunk
  importVersion = config.CURRENT_IMPORT_VERSION

  loader = new DataLoader formattedFilingsFromObjectIdsLoaderFn
  Promise.map modifiedModel990s, (modifiedModel990) ->
    {objectId, ein, year, returnVersion} = modifiedModel990
    isValidVersion = config.VALID_RETURN_VERSIONS.indexOf(returnVersion) isnt -1
    if isValidVersion
      # only run irsx if we know it won't fail.
      filingJson = await loader.load(objectId)
      formattedFiling = await processFilingFn filingJson
      {model, model990, persons, contributions} = formattedFiling

    model = _.defaults {ein}, model
    # even if we didn't run irsx, we still want to update w/ returnVersion
    model990 = _.defaults model990, modifiedModel990
    model990 = _.defaults {importVersion}, model990
    persons = _.map persons, (person) -> _.defaults {ein}, person
    contributions = _.map contributions, (contribution) ->
      _.defaults {ein}, contribution

    {model, model990, persons, contributions}
  .then (filingResults) ->
    console.log 'Processed', filingResults.length, 'in', Date.now() - start, 'ms'

    processResultsFn filingResults


module.exports = {
  upsertOrgs: ({orgs, i}) ->
    IrsOrg.batchUpsert orgs
    .then ->
      console.log 'upserted', i

  processOrgChunk: ({chunk}) ->
    processChunk {
      chunk
      Model990: IrsOrg990
      processFilingFn: (filing) ->
        if filing.IRS990
          processOrgFiling filing
        else
          processOrgEZFiling filing
      processResultsFn: (filingResults) ->
        start = Date.now()
        orgs = _.filter _.map filingResults, 'model'
        org990s = _.filter _.map filingResults, 'model990'
        persons = _.filter _.flatten _.map filingResults, 'persons'

        Promise.all _.filter [
          if orgs.length
            IrsOrg.batchUpsert orgs
          if org990s.length
            # since it's entire doc, "index" instead of update (upsert). much faster
            IrsOrg990.batchUpsert org990s, {ESIndex: true}
          if persons.length
            # since it's entire doc, "index" instead of update (upsert). much faster
            IrsPerson.batchUpsert persons, {ESIndex: true}
        ]
        .then ->
          console.log "Upserted #{orgs.length} orgs #{org990s.length} 990s #{persons.length} persons in #{Date.now() - start}"

    }

  processFundChunk: ({chunk}) ->
    processChunk {
      chunk
      Model990: IrsFund990
      processFilingFn: processFundFiling
      processResultsFn: (filingResults) ->
        start = Date.now()
        funds = _.filter _.map filingResults, 'model'
        fund990s = _.filter _.map filingResults, 'model990'
        persons = _.filter _.flatten _.map filingResults, 'persons'
        contributions = _.filter _.flatten _.map filingResults, 'contributions'

        Promise.all _.filter [
          if funds.length
            IrsFund.batchUpsert funds
          if fund990s.length
            # since it's entire doc, "index" instead of update (upsert). much faster
            IrsFund990.batchUpsert fund990s, {ESIndex: true}
          if persons.length
            # since it's entire doc, "index" instead of update (upsert). much faster
            IrsPerson.batchUpsert persons, {ESIndex: true}
          if contributions.length
            # since it's entire doc, "index" instead of update (upsert). much faster
            IrsContribution.batchUpsert contributions, {ESIndex: true}
        ]
        .then ->
          console.log "Upserted #{funds.length} funds #{fund990s.length} 990s #{persons.length} persons, #{contributions.length} contributions in #{Date.now() - start}"
    }

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

# # FIXME: rm
# module.exports.processFundChunk({chunk: [objectId: '201623169349100822']})
# getFilingJsonFromObjectId '201623169349100822' # b&m gates
# .then (filing) ->
#   # console.log 'f', filing
#   res = await processFundFiling filing
#   console.log 'res', res.fund
