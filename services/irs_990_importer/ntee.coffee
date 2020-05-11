_ = require 'lodash'
requestNonPromise = require 'request'
csv = require 'csvtojson'
fs = require 'fs'
stringSimilarity = require 'string-similarity'

IrsOrg = require '../../graphql/irs_org/model'
JobCreateService = require '../../services/job_create'
CacheService = require '../../services/cache'

module.exports = {
  setNtee: ->
    console.log 'sync'
    cache = null
    requestNonPromise('https://nccs-data.urban.org/data/bmf/2019/bmf.bm1908.csv')
    .pipe(fs.createWriteStream('data.csv'))
    .on 'finish', ->
      console.log 'file downloaded'
      chunk = []
      i = 0
      csv().fromFile('data.csv')
      .subscribe ((json) ->
        i += 1
        if i and not (i % 100)
          console.log i
          cache = chunk
          chunk = []
          JobCreateService.createJob {
            queueKey: 'DEFAULT'
            waitForCompletion: true
            job: {orgs: cache, i}
            type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_UPSERT_ORGS
            ttlMs: 60000
            priority: JobCreateService.PRIORITIES.NORMAL
          }
          .catch (err) ->
            console.log 'err', err
        # console.log json
        chunk.push {
          ein: json.EIN
          name: json.NAME
          city: json.CITY
          state: json.STATE
          nteecc: json.NTEECC
        }
      ), (-> console.log 'error'), ->
        console.log 'done'
        IrsOrg.batchUpsert cache

  getEinNteeFromNameCityState: (name, city, state) ->
    name = name?.toLowerCase() or ''
    city = city?.toLowerCase() or ''
    state = state?.toLowerCase() or ''
    key = "#{CacheService.PREFIXES.EIN_FROM_NAME}:#{name}:#{city}:#{state}"
    CacheService.preferCache key, ->
      IrsOrg.search {
        limit: 1
        query:
          multi_match:
            query: name
            type: 'bool_prefix'
            fields: ['name', 'name._2gram']
      }
      .then (orgs) ->
        closeEnough = _.filter _.map orgs.rows, (org) ->
          unless org.name
            return 0
          score = stringSimilarity.compareTwoStrings(org.name.toLowerCase(), name)
          # console.log score
          if score > 0.7
            _.defaults {score}, org
        cityMatches = _.filter _.map closeEnough, (org) ->
          unless org.city
            return 0
          if city
            cityScore = stringSimilarity.compareTwoStrings(org.city.toLowerCase(), city)
          else
            cityScore = 1
          if cityScore > 0.8
            _.defaults {cityScore: city}, org

        match = _.maxBy cityMatches, ({score, cityScore}) -> "#{cityScore}|#{score}"
        unless match
          match = _.maxBy closeEnough, 'score'

        if match
          {
            ein: match?.ein
            nteecc: match?.nteecc
          }
        else
          null
        # TODO: can also look at grant amount and income to help find best match
    , {expireSeconds: 1}# FIXME 3600 * 24}
}
