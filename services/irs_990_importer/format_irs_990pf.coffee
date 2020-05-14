_ = require 'lodash'
Promise = require 'bluebird'

{formatInt, formatBigInt, formatWebsite, formatFloat, getOrgNameByFiling} = require './helpers'
{getEinNteeFromNameCityState} = require './ntee'
config = require '../../config'

module.exports = {
  getFund990Json: (filing) ->
    entityName = getOrgNameByFiling filing

    website = formatWebsite filing.IRS990PF.parts.pf_part_viia?.SttmntsRgrdngActy_WbstAddrssTxt

    {
      importVersion: config.CURRENT_IMPORT_VERSION
      ein: filing.ReturnHeader.ein
      name: entityName
      city: filing.ReturnHeader.USAddrss_CtyNm
      state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd
      # year: filing.ReturnHeader.RtrnHdr_TxYr
      year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
      objectId: "#{filing.objectId}"
      website: website

      revenue: _.pickBy
        contributionsAndGrants: formatBigInt filing.IRS990PF.parts.pf_part_i?.CntrRcvdRvAndExpnssAmt
        interestOnSavings: formatBigInt filing.IRS990PF.parts.pf_part_i?.IntrstOnSvRvAndExpnssAmt
        dividendsFromSecurities: formatBigInt filing.IRS990PF.parts.pf_part_i?.DvdndsRvAndExpnssAmt
        netRental: formatBigInt filing.IRS990PF.parts.pf_part_i?.NtRntlIncmOrLssAmt
        netAssetSales: formatBigInt filing.IRS990PF.parts.pf_part_i?.NtGnSlAstRvAndExpnssAmt
        capitalGain: formatBigInt filing.IRS990PF.parts.pf_part_i?.CpGnNtIncmNtInvstIncmAmt
        capitalGainShortTerm: formatBigInt filing.IRS990PF.parts.pf_part_i?.NtSTCptlGnAdjNtIncmAmt
        incomeModifications: formatBigInt filing.IRS990PF.parts.pf_part_i?.IncmMdfctnsAdjNtIncmAmt
        grossSales: formatBigInt filing.IRS990PF.parts.pf_part_i?.GrssPrftAdjNtIncmAmt
        other: formatBigInt filing.IRS990PF.parts.pf_part_i?.OthrIncmRvAndExpnssAmt
        # **
        total: formatBigInt filing.IRS990PF.parts.pf_part_i?.TtlRvAndExpnssAmt

      expenses: _.pickBy
        officerSalaries: formatBigInt filing.IRS990PF.parts.pf_part_i?.CmpOfcrDrTrstRvAndExpnssAmt
        nonOfficerSalaries: formatBigInt filing.IRS990PF.parts.pf_part_i?.OthEmplSlrsWgsRvAndExpnssAmt
        employeeBenefits: formatBigInt filing.IRS990PF.parts.pf_part_i?.PnsnEmplBnftRvAndExpnssAmt
        legalFees: formatBigInt filing.IRS990PF.parts.pf_part_i?.LglFsRvAndExpnssAmt
        accountingFees: formatBigInt filing.IRS990PF.parts.pf_part_i?.AccntngFsRvAndExpnssAmt
        otherProfessionalFees: formatBigInt filing.IRS990PF.parts.pf_part_i?.OthrPrfFsRvAndExpnssAmt
        interest: formatBigInt filing.IRS990PF.parts.pf_part_i?.IntrstRvAndExpnssAmt
        taxes: formatBigInt filing.IRS990PF.parts.pf_part_i?.TxsRvAndExpnssAmt
        depreciation: formatBigInt filing.IRS990PF.parts.pf_part_i?.DprcAndDpltnRvAndExpnssAmt
        occupancy: formatBigInt filing.IRS990PF.parts.pf_part_i?.OccpncyRvAndExpnssAmt # rent
        travel: formatBigInt filing.IRS990PF.parts.pf_part_i?.TrvCnfMtngRvAndExpnssAmt
        printing: formatBigInt filing.IRS990PF.parts.pf_part_i?.PrntngAndPbNtInvstIncmAmt
        other: formatBigInt filing.IRS990PF.parts.pf_part_i?.OthrExpnssRvAndExpnssAmt
        # **
        totalOperations: formatBigInt filing.IRS990PF.parts.pf_part_i?.TtOprExpnssRvAndExpnssAmt
        # **
        contributionsAndGrants: formatBigInt filing.IRS990PF.parts.pf_part_i?.CntrPdRvAndExpnssAmt
        total: formatBigInt filing.IRS990PF.parts.pf_part_i?.TtlExpnssRvAndExpnssAmt

      # **
      netIncome: formatBigInt filing.IRS990PF.parts.pf_part_i?.ExcssRvnOvrExpnssAmt

      assets:
        boy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlAsstsBOYAmt
        eoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlAsstsEOYAmt

      liabilities:
        boy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlLbltsBOYAmt
        eoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlLbltsEOYAmt

      netAssets:
        boy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtNtAstOrFndBlncsBOYAmt
        eoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtNtAstOrFndBlncsEOYAmt

      # TODO: could do some activities on whether or not they do political stuff (viia)
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
        benefits: formatInt person.OffcrDrTrstKyEmpl_EmplyBnftPrgrmAmt
        expenseAccount: formatInt person.OffcrDrTrstKyEmpl_ExpnsAccntOthrAllwncAmt
      }

  getContributionsJson: (filing) ->
    contributions = _.map filing.IRS990PF.groups.PFGrntOrCntrbtnPdDrYr, (contribution) ->
      city = contribution.RcpntUSAddrss_CtyNm
      state = contribution.RcpntUSAddrss_SttAbbrvtnCd
      businessName = contribution.RcpntBsnssNm_BsnssNmLn1Txt
      if contribution.RcpntBsnssNm_BsnssNmLn2Txt
        businessName += " #{contribution.RcpntBsnssNm_BsnssNmLn2Txt}"

      type = if businessName \
             then 'org' \
             else if contribution.GrntOrCntrbtnPdDrYr_RcpntPrsnNm \
             then 'person' \
             else 'unknown'

      {
        year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
        fromEin: filing.ReturnHeader.ein
        toName: businessName or contribution.GrntOrCntrbtnPdDrYr_RcpntPrsnNm
        toCity: city
        toState: state
        type: type
        toExemptStatus: contribution.GrntOrCntrbtnPdDrYr_RcpntFndtnSttsTxt
        amount: formatBigInt contribution.GrntOrCntrbtnPdDrYr_Amt
        relationship: contribution.GrntOrCntrbtnPdDrYr_RcpntRltnshpTxt
        purpose: contribution.GrntOrCntrbtnPdDrYr_GrntOrCntrbtnPrpsTxt
      }

    contributions = await Promise.map contributions, (contribution) ->
      {toName, toCity, toState} = contribution
      einNtee = getEinNteeFromNameCityState(toName, toCity, toState)
      {ein, nteecc} = einNtee or {}
      contribution = _.defaults {
        toId: ein or toName
      }, contribution
      unless contribution.toId
        console.log 'contribution missing toId', contribution
      if nteecc
        contribution.nteeMajor = nteecc.substr(0, 1)
        contribution.nteeMinor = nteecc.substr(1)

      contribution
    , {concurrency: 5}

    # combine contributions w/ same toId
    groupedContributions = _.groupBy contributions, 'toId'
    _.map groupedContributions, (contributions) ->
      amount = _.sumBy(contributions, 'amount')
      _.defaults {amount}, contributions[0]


}
