_ = require 'lodash'
Promise = require 'bluebird'

{formatInt, formatWebsite, formatFloat, getOrgNameByFiling} = require './helpers'
{getEinNteeFromNameCityState} = require './ntee'

module.exports = {
  getFund990Json: (filing) ->
    entityName = getOrgNameByFiling filing

    website = formatWebsite filing.IRS990PF.parts.pf_part_viia?.SttmntsRgrdngActy_WbstAddrssTxt

    {
      isProcessed: true
      ein: filing.ReturnHeader.ein
      name: entityName
      city: filing.ReturnHeader.USAddrss_CtyNm
      state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd
      # year: filing.ReturnHeader.RtrnHdr_TxYr
      year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
      objectId: "#{filing.objectId}"
      website: website

      # contributionsReceived: formatInt filing.IRS990PF.parts.pf_part_i?.CntrRcvdRvAndExpnssAmt
      # grossProfit: formatInt filing.IRS990PF.parts.pf_part_i?.GrssPrftRvAndExpnssAmt
      # FIXME: learn
      # income:
      #   net: filing.IRS990PF.parts.pf_part_i?.GrssPrftAdjNtIncmAmt
      #   other: filing.IRS990PF.parts.pf_part_i?.OthrIncmRvAndExpnssAmt
      #   investment: filing.IRS990PF.parts.pf_part_i?.OthrIncmNtInvstIncmAmt
      # expenses:
      #   officerCompensation: filing.IRS990PF.parts.pf_part_i?.CmpOfcrDrTrstDsbrsChrtblAmt

    }

  # 990pf
  getFundJson: (fund990, existing990s) ->
    fund = {
      ein: fund990.ein
      name: fund990.name
      city: fund990.city
      state: fund990.state
      website: fund990.website
    }

    maxExistingYear = _.maxBy existing990s, 'year'
    if fund990.year >= maxExistingYear or not maxExistingYear
      fund.maxYear = fund990.year

    fund

  getFundPersonsJson: (filing) ->
    entityName = getOrgNameByFiling filing

    _.map filing.IRS990PF.groups.PFOffcrDrTrstKyEmpl, (person) ->
      businessName = person.OffcrDrTrstKyEmpl_BsnssNmLn1
      if person.OffcrDrTrstKyEmpl_BsnssNmLn2
        businessName += " #{person.OffcrDrTrstKyEmpl_BsnssNmLn2}"
      {
        name: person.OffcrDrTrstKyEmpl_PrsnNm or businessName
        ein: filing.ReturnHeader.ein
        entityName: entityName
        entityType: 'fund'
        year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
        isBusiness: Boolean businessName
        title: person.OffcrDrTrstKyEmpl_TtlTxt
        weeklyHours: formatFloat person.OffcrDrTrstKyEmpl_AvrgHrsPrWkDvtdTPsRt
        compensation: formatInt person.OffcrDrTrstKyEmpl_CmpnstnAmt
        expenseAccount: formatInt person.OffcrDrTrstKyEmpl_ExpnsAccntOthrAllwncAmt
      }

  getContributionsJson: (filing) =>
    contributions = _.map filing.IRS990PF.groups.PFGrntOrCntrbtnPdDrYr, (contribution) ->
      city = contribution.RcpntUSAddrss_CtyNm
      state = contribution.RcpntUSAddrss_SttAbbrvtnCd
      businessName = contribution.RcpntBsnssNm_BsnssNmLn1Txt
      if contribution.RcpntBsnssNm_BsnssNmLn2Txt
        businessName += " #{contribution.RcpntBsnssNm_BsnssNmLn2Txt}"

      {
        year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
        fromEin: filing.ReturnHeader.ein
        toName: businessName or contribution.GrntOrCntrbtnPdDrYr_RcpntPrsnNm
        toCity: city
        toState: state
        # toPersonName: contribution.GrntOrCntrbtnPdDrYr_RcpntPrsnNm
        toExemptStatus: contribution.GrntOrCntrbtnPdDrYr_RcpntFndtnSttsTxt
        amount: formatInt contribution.GrntOrCntrbtnPdDrYr_Amt
        relationship: contribution.GrntOrCntrbtnPdDrYr_RcpntRltnshpTxt
        purpose: contribution.GrntOrCntrbtnPdDrYr_GrntOrCntrbtnPrpsTxt
        # TODO: need to get ein from org search
      }
    contributions = await Promise.map contributions, (contribution) =>
      {toName, toCity, toState} = contribution
      @getEinNteeFromNameCityState(toName, toCity, toState)
      .then ({ein, nteecc} = {}) ->
        contribution = _.defaults {
          toId: ein or toName
        }, contribution
        unless contribution.toId
          console.log contribution
        if nteecc
          contribution.nteeMajor = nteecc.substr(0, 1)
          contribution.nteeMinor = nteecc.substr(1)

        contribution
    , {concurrency: 5}

    # FIXME: sum all contribution amounts per toId
    # contributions = _.groupBy(contributions, 'toId')
}
