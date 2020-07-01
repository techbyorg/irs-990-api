import _ from 'lodash'
import request from 'request-promise'
import { spawn } from 'child_process'

import Promise from 'bluebird'
import cheerio from 'cheerio'
import DataLoader from 'dataloader'
import fs from 'fs-extra'

import { getNonprofit990Json, getNonprofitJson, getNonprofitPersonsJson } from './format_irs_990.js'
import { getNonprofit990EZJson, getNonprofitEZPersonsJson } from './format_irs_990ez.js'
import { getFund990Json, getFundJson, getFundPersonsJson, getContributionsJson } from './format_irs_990pf.js'
import IrsContribution from '../../graphql/irs_contribution/model.js'
import IrsFund from '../../graphql/irs_fund/model.js'
import IrsFund990 from '../../graphql/irs_fund_990/model.js'
import IrsNonprofit from '../../graphql/irs_nonprofit/model.js'
import IrsNonprofit990 from '../../graphql/irs_nonprofit_990/model.js'
import IrsPerson from '../../graphql/irs_person/model.js'
import config from '../../config.js'

const irsxEnv = _.defaults({
  IRSX_XML_HTTP_BASE: config.IRSX_XML_HTTP_BASE,
  IRSX_CACHE_DIRECTORY: config.IRSX_CACHE_DIRECTORY
}, _.clone(process.env))

async function processNonprofitFiling (filing, { ein, year }) {
  const existing990s = await IrsNonprofit990.getAllByEin(filing.ReturnHeader.ein)
  const nonprofit990 = getNonprofit990Json(filing, { ein, year })
  const nonprofitPersons = getNonprofitPersonsJson(filing)
  return {
    model: getNonprofitJson(nonprofit990, nonprofitPersons, existing990s),
    model990: nonprofit990,
    persons: nonprofitPersons
  }
}

async function processNonprofitEZFiling (filing, { ein, year }) {
  const existing990s = await IrsNonprofit990.getAllByEin(filing.ReturnHeader.ein)
  const nonprofit990 = getNonprofit990EZJson(filing, { ein, year })
  const nonprofitPersons = getNonprofitEZPersonsJson(filing)
  return {
    model: getNonprofitJson(nonprofit990, nonprofitPersons, existing990s),
    model990: nonprofit990,
    persons: nonprofitPersons
  }
}

async function processFundFiling (filing, { ein, year }) {
  const existing990s = await IrsFund990.getAllByEin(ein)
  const fund990 = getFund990Json(filing, { ein, year })
  const fundPersons = getFundPersonsJson(filing)
  const contributions = await getContributionsJson(filing)
  return {
    model: getFundJson(fund990, fundPersons, contributions, existing990s),
    model990: fund990,
    persons: fundPersons,
    contributions
  }
}

function convertFiling (filing) {
  return _.reduce(filing, function (obj, part) {
    if (part.schedule_name === 'ReturnHeader990x') {
      obj.ReturnHeader = part.schedule_parts.returnheader990x_part_i
    } else if (part.schedule_name) {
      obj[part.schedule_name] = {
        parts: part.schedule_parts,
        groups: part.groups
      }
    }
    return obj
  }, {})
}

function add990Versions (chunk) {
  return Promise.map(chunk, async function (model990) {
    let err, returnVersion
    const fileName = `${model990.objectId}_public.xml`
    try {
      const xml = await request(`${config.IRSX_XML_HTTP_BASE}/${fileName}`)
      try {
        // since we've already downloaded, store in cache for irsx to use...
        await fs.outputFile(`${config.IRSX_CACHE_DIRECTORY}/XML/${fileName}`, xml)
      } catch (error) {
        err = error
        console.log(err)
      }
      returnVersion = xml.match(/returnVersion="(.*?)"/i)?.[1]
    } catch (error1) {
      err = error1
      returnVersion = null
    }

    return _.defaults({ returnVersion }, model990)
  })
}

async function add990Filings (modifiedModel990s, { Model990 }) {
  const formattedFilingsFromObjectIdsLoaderFn = (objectIds) => {
    try {
      return getFilingJsonFromObjectIds(objectIds)
    } catch (err) {
      // if irsx fails on bulk, do 1 by 1 so we at least get the working ones
      console.log('doing 1 by 1', err)
      return Promise.map(objectIds, objectId => getFilingJsonFromObjectIds([objectId])
        .then(([filingJson]) => filingJson)
        .catch(async function () {
          console.log(`json parse fail: ${objectId}`)
          await Model990.upsertByRow(Model990, {
            importVersion: config.CURRENT_IMPORT_VERSION
          })
          return null
        }))
    }
  }

  const loader = new DataLoader(formattedFilingsFromObjectIdsLoaderFn)
  modifiedModel990s = await Promise.map(modifiedModel990s, async function (modifiedModel990) {
    let filingJson
    const { objectId, returnVersion } = modifiedModel990
    const isValidVersion = config.VALID_RETURN_VERSIONS.indexOf(returnVersion) !== -1
    if (isValidVersion) {
      // only run irsx if we know it won't fail.
      filingJson = await loader.load(objectId)
    }
    return _.defaults({ filingJson }, modifiedModel990)
  })
  return modifiedModel990s
}

async function getFilingJsonFromObjectIds (objectIds) {
  const jsonStr = await new Promise(function (resolve, reject) {
    const child = spawn('irsx', objectIds, {
      env: irsxEnv
    })
    let str = ''
    child.stdout.on('data', chunk => { str += chunk })
    child.on('error', function (error) {
      console.log('err', error)
      return reject(error)
    })
    return child.on('close', function (code, signal) {
      if (code !== 0) {
        console.log('code not 0', code, signal)
        reject(new Error('failure'))
      }
      return resolve(`[${str.replace(/\]\[/g, '],[')}]`)
    })
  })

  const filings = (() => {
    try {
      return JSON.parse(jsonStr)
    } catch (err) {
      throw new Error('json parse fail')
    }
  })()

  return _.map(filings, function (filing, i) {
    const formattedFiling = convertFiling(filing)
    return _.defaults({ objectId: objectIds[i] }, formattedFiling)
  })
}

async function processChunk (options) {
  const {
    chunk, Model990, processFilingFn, processResultsFn,
    chunkConcurrency
  } = options

  let start = Date.now()
  let modifiedModel990s = await add990Versions(chunk)
  modifiedModel990s = await add990Filings(modifiedModel990s, { Model990 })

  console.log('IRSX\'d', modifiedModel990s.length, 'in', Date.now() - start, 'ms')
  start = Date.now()

  const importVersion = config.CURRENT_IMPORT_VERSION
  const concurrency = chunkConcurrency
    ? parseInt(chunkConcurrency)
    : chunk.length

  // break this into 2 maps because this 2nd one is the one we want to limit
  // with chunkConcurrency (due to es fetches)
  const filingResults = await Promise.map(modifiedModel990s, async function (modifiedModel990) {
    let contributions, model, model990, persons
    const { filingJson, ein, year } = modifiedModel990
    if (filingJson) {
      const formattedFiling = await processFilingFn(filingJson, { ein, year });
      ({ model, model990, persons, contributions } = formattedFiling)
    }

    model = _.defaults({ ein }, model)
    // even if we didn't run irsx, we still want to update w/ returnVersion
    model990 = _.defaults(model990, modifiedModel990)
    delete model990.filingJson
    model990 = _.defaults({ importVersion }, model990)
    persons = _.map(persons, person => _.defaults({ ein }, person))
    contributions = _.map(contributions, contribution => _.defaults({ fromEin: ein }, contribution))

    return { model, model990, persons, contributions }
  }
  , { concurrency })

  console.log('Processed', filingResults.length, 'in', Date.now() - start, 'ms')

  return processResultsFn(filingResults)
}

export default {
  upsertNonprofits ({ nonprofits, i }) {
    return IrsNonprofit.batchUpsert(nonprofits)
      .then(() => console.log('upserted', i))
  },

  processNonprofitChunk ({ chunk, chunkConcurrency }) {
    return processChunk({
      chunk,
      chunkConcurrency,
      Model990: IrsNonprofit990,
      processFilingFn (filing, { ein, year }) {
        if (filing.IRS990) {
          return processNonprofitFiling(filing, { ein, year })
        } else {
          return processNonprofitEZFiling(filing, { ein, year })
        }
      },
      processResultsFn (filingResults) {
        const start = Date.now()
        const nonprofits = _.filter(_.map(filingResults, 'model'))
        const nonprofit990s = _.filter(_.map(filingResults, 'model990'))
        const persons = _.filter(_.flatten(_.map(filingResults, 'persons')))

        return Promise.all(_.filter([
          nonprofits.length
            ? IrsNonprofit.batchUpsert(nonprofits) : undefined,
          nonprofit990s.length
            // since it's entire doc, "index" instead of update (upsert). much faster
            ? IrsNonprofit990.batchUpsert(nonprofit990s, { ESIndex: true }) : undefined,
          persons.length
            // since it's entire doc, "index" instead of update (upsert). much faster
            ? IrsPerson.batchUpsert(persons, { ESIndex: true }) : undefined
        ]))
          .then(() => console.log(`Upserted ${nonprofits.length} nonprofits ${nonprofit990s.length} 990s ${persons.length} persons in ${Date.now() - start}`))
      }

    })
  },

  processFundChunk ({ chunk, chunkConcurrency }) {
    return processChunk({
      chunk,
      chunkConcurrency,
      Model990: IrsFund990,
      processFilingFn: processFundFiling,
      processResultsFn (filingResults) {
        const start = Date.now()
        const funds = _.filter(_.map(filingResults, 'model'))
        const fund990s = _.filter(_.map(filingResults, 'model990'))
        const persons = _.filter(_.flatten(_.map(filingResults, 'persons')))
        const contributions = _.filter(_.flatten(_.map(filingResults, 'contributions')))

        return Promise.all(_.filter([
          funds.length
            ? IrsFund.batchUpsert(funds) : undefined,
          fund990s.length
            // since it's entire doc, "index" instead of update (upsert). much faster
            ? IrsFund990.batchUpsert(fund990s, { ESIndex: true }) : undefined,
          persons.length
            // since it's entire doc, "index" instead of update (upsert). much faster
            ? IrsPerson.batchUpsert(persons, { ESIndex: true }) : undefined,
          contributions.length
            // since it's entire doc, "index" instead of update (upsert). much faster
            // FIXME: don't have ES id use ntee since that can change?
            // TODO: test that scylla obj gets updated (and not duped)
            ? IrsContribution.batchUpsert(contributions, { ESIndex: true }) : undefined
        ]))
          .then(() => console.log(`Upserted ${funds.length} funds ${fund990s.length} 990s ${persons.length} persons, ${contributions.length} contributions in ${Date.now() - start}`))
      }
    })
  },

  async parseWebsite ({ ein, counter }) {
    const irsNonprofit = await IrsNonprofit.getByEin(ein)

    return request({
      uri: irsNonprofit.website,
      headers: {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36'
      }
    })
      .then(function (html) {
        const $ = cheerio.load(html)
        let text = $.text().toLowerCase()
        text = text.replace(/\s+/g, ' ')
        console.log('upsert', text.length)
        return IrsNonprofit.upsertByRow(irsNonprofit, {
          websiteText: text.substr(0, 10000)
        })
      })
      .catch(() => {
        console.log('website err', irsNonprofit.website)
      })
      .then(() => console.log(counter))
  }
}

// # FIXME: rm
// module.exports.processFundChunk({chunk: [objectId: '201623169349100822']})
// getFilingJsonFromObjectId '201623169349100822' # b&m gates
// .then (filing) ->
//   # console.log 'f', filing
//   res = await processFundFiling filing
//   console.log 'res', res.fund
