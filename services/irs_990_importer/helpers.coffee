normalizeUrl = require 'normalize-url'

module.exports = {
  formatInt: (int) -> if int? then parseInt(int) else null
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

}
