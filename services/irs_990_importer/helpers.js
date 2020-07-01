import normalizeUrl from 'normalize-url'
import _ from 'lodash'
import { cknex } from 'backend-shared'

export function formatInt (int) {
  if (int != null) {
    return parseInt(int)
  } else {
    return null
  }
}
// cassanknex doesn't use v4 of cassandra-driver which supports `BigInt`, so have to use Long
export function formatBigInt (bigint) {
  if (bigint != null) {
    return cknex.Long.fromValue(bigint)
  } else {
    return null
  }
}
export function formatFloat (float) {
  if (float != null) {
    return parseFloat(float)
  } else {
    return null
  }
}
export function formatWebsite (website) {
  if (website && (website !== 'N/A')) {
    try {
      website = normalizeUrl(website)
    } catch (err) {}
  }
  return website
}
export function getNonprofitNameByFiling (filing) {
  let entityName = filing.ReturnHeader.BsnssNm_BsnssNmLn1Txt
  if (filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt) {
    entityName += ` ${filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt}`
  }
  return entityName
}

export function roundTwoDigits (num) {
  return Math.round(num * 100) / 100
}

export function sumByLong (arr, key) {
  return _.reduce(arr, function (long, row) {
    if (row[key]) {
      long = long.add(row[key])
    }
    return long
  }
  , cknex.Long.fromValue(0))
}
