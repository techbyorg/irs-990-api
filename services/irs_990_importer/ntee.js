import _ from 'lodash';
import stringSimilarity from 'string-similarity';
import { Cache } from 'backend-shared';
import IrsOrg from '../../graphql/irs_org/model';
import CacheService from '../../services/cache';

export default {
  getEinNteeFromNameCityState(name, city, state) {
    name = name?.toLowerCase() || '';
    city = city?.toLowerCase() || '';
    state = state?.toLowerCase() || '';
    const key = `${CacheService.PREFIXES.EIN_FROM_NAME}:${name}:${city}:${state}`;
    return Cache.preferCache(key, async function() {
      const orgs = await IrsOrg.search({
        limit: 10,
        query: {
          multi_match: {
            query: name,
            type: 'bool_prefix',
            fields: ['name', 'name._2gram']
          }
        }
      });

      const closeEnough = _.filter(_.map(orgs.rows, function(org) {
        if (!org.name) {
          return 0;
        }
        const score = stringSimilarity.compareTwoStrings(org.name.toLowerCase(), name);
        // console.log score
        if (score > 0.7) {
          return _.defaults({score}, org);
        }
      })
      );
      const cityMatches = _.filter(_.map(closeEnough, function(org) {
        let cityScore;
        if (!org.city) {
          return 0;
        }
        if (city) {
          cityScore = stringSimilarity.compareTwoStrings(org.city.toLowerCase(), city);
        } else {
          cityScore = 1;
        }
        if (cityScore > 0.8) {
          return _.defaults({cityScore: city}, org);
        }
      })
      );

      let match = _.maxBy(cityMatches, ({score, cityScore}) => `${cityScore}|${score}`);
      if (!match) {
        match = _.maxBy(closeEnough, 'score');
      }

      if (match) {
        return {
          ein: match?.ein,
          nteecc: match?.nteecc
        };
      } else {
        return null;
      }
    }
      // TODO: can also look at grant amount and income to help find best match
    , {expireSeconds: 3600 * 24});
  }
};
