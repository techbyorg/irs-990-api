normalizeUrl = require 'normalize-url'
{cknex} = require 'phil-helpers'

module.exports = {
  formatInt: (int) -> if int? then parseInt(int) else null
  # cassanknex doesn't use v4 of cassandra-driver which supports `BigInt`, so have to use Long
  formatBigInt: (bigint) -> if bigint? then cknex.Long.fromValue(bigint) else null
  formatFloat: (float) -> if float? then parseFloat(float) else null
  formatWebsite: (website) ->
    if website and website isnt 'N/A'
      try
        website = normalizeUrl website
      catch err
        null
    website
  getOrgNameByFiling: (filing) ->
    entityName = filing.ReturnHeader.BsnssNm_BsnssNmLn1Txt
    if filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt
      entityName += " #{filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt}"
    entityName

  roundTwoDigits: (num) ->
    Math.round(num * 100) / 100
}
