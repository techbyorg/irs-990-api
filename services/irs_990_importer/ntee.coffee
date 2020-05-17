_ = require 'lodash'
stringSimilarity = require 'string-similarity'
{Cache} = require 'phil-helpers'

IrsOrg = require '../../graphql/irs_org/model'
CacheService = require '../../services/cache'

module.exports = {
  getEinNteeFromNameCityState: (name, city, state) ->
    name = name?.toLowerCase() or ''
    city = city?.toLowerCase() or ''
    state = state?.toLowerCase() or ''
    key = "#{CacheService.PREFIXES.EIN_FROM_NAME}:#{name}:#{city}:#{state}"
    Cache.preferCache key, ->
      orgs = await IrsOrg.search {
        limit: 10
        query:
          multi_match:
            query: name
            type: 'bool_prefix'
            fields: ['name', 'name._2gram']
      }

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
    , {expireSeconds: 3600 * 24}
}
