import normalizeUrl from 'normalize-url'
import _ from 'lodash'
import { cknex } from 'backend-shared'

export default {
  formatInt (int) {
    if (int != null) {
      return parseInt(int)
    } else {
      return null
    }
  },
  // cassanknex doesn't use v4 of cassandra-driver which supports `BigInt`, so have to use Long
  formatBigInt (bigint) {
    if (bigint != null) {
      return cknex.Long.fromValue(bigint)
    } else {
      return null
    }
  },
  formatFloat (float) {
    if (float != null) {
      return parseFloat(float)
    } else {
      return null
    }
  },
  formatWebsite (website) {
    if (website && (website !== 'N/A')) {
      try {
        website = normalizeUrl(website)
      } catch (err) {}
    }
    return website
  },
  getOrgNameByFiling (filing) {
    let entityName = filing.ReturnHeader.BsnssNm_BsnssNmLn1Txt
    if (filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt) {
      entityName += ` ${filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt}`
    }
    return entityName
  },

  roundTwoDigits (num) {
    return Math.round(num * 100) / 100
  },

  sumByLong (arr, key) {
    return _.reduce(arr, function (long, row) {
      if (row[key]) {
        long = long.add(row[key])
      }
      return long
    }
    , cknex.Long.fromValue(0))
  }
}
