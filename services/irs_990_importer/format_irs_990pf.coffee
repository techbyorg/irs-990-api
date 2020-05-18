_ = require 'lodash'
Promise = require 'bluebird'
md5 = require 'md5'

{formatInt, formatBigInt, formatWebsite, formatFloat, getOrgNameByFiling} = require './helpers'
{getEinNteeFromNameCityState} = require './ntee'

module.exports = {
  getFund990Json: (filing, {ein, year}) ->
    entityName = getOrgNameByFiling filing

    website = formatWebsite filing.IRS990PF.parts.pf_part_viia?.SttmntsRgrdngActy_WbstAddrssTxt

    # us address
    if filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntUSAddrss_ZIPCd
      applicantSubmissionAddress =
        street1: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntUSAddrss_AddrssLn1Txt
        street2: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntUSAddrss_AddrssLn2Txt
        postalCode: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntUSAddrss_ZIPCd
        city: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntUSAddrss_CtyNm
        state: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntUSAddrss_SttAbbrvtnCd
        countryCode: 'US'
    # foreign address
    else if filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntFrgnAddrss_FrgnPstlCd
      street1: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntFrgnAddrss_AddrssLn1Txt
      street2: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntFrgnAddrss_AddrssLn2Txt
      postalCode: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntFrgnAddrss_FrgnPstlCd
      city: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntFrgnAddrss_CtyNm
      state: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntFrgnAddrss_PrvncOrSttNm
      countryCode: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.RcpntFrgnAddrss_CntryCd
    else
      applicantSubmissionAddress = null

    {
      ein
      year
      name: entityName
      city: filing.ReturnHeader.USAddrss_CtyNm
      state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd
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

      assets: _.pickBy
        cashBoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.CshBOYAmt
        cashEoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.CshEOYAmt
        boy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlAsstsBOYAmt
        eoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlAsstsEOYAmt

      liabilities: _.pickBy
        boy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlLbltsBOYAmt
        eoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtlLbltsEOYAmt

      netAssets: _.pickBy
        boy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtNtAstOrFndBlncsBOYAmt
        eoy: formatBigInt filing.IRS990PF.parts.pf_part_ii?.TtNtAstOrFndBlncsEOYAmt

      applicantInfo: _.pickBy
        acceptsUnsolicitedRequests: !filing.IRS990PF.parts.pf_part_xv?.OnlyCntrTPrslctdInd
        address: applicantSubmissionAddress
        recipientName: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.ApplctnSbmssnInf_RcpntPrsnNm
        requirements: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.ApplctnSbmssnInf_FrmAndInfAndMtrlsTxt
        deadlines: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.ApplctnSbmssnInf_SbmssnDdlnsTxt
        restrictions: filing.IRS990PF.groups.PFApplctnSbmssnInf?[0]?.ApplctnSbmssnInf_RstrctnsOnAwrdsTxt

      directCharitableActivities:
        lineItems: _.filter _.map _.range(4), (i) ->
          if filing.IRS990PF.parts.pf_part_ixa?["Dscrptn#{i}Txt"]
            {
              description: filing.IRS990PF.parts.pf_part_ixa["Dscrptn#{i}Txt"]
              expenses: formatBigInt(filing.IRS990PF.parts.pf_part_ixa["Expnss#{i}Amt"]) or 0
            }

      programRelatedInvestments: _.pickBy
        lineItems:  _.filter _.map _.range(4), (i) ->
          if filing.IRS990PF.parts.pf_part_ixb?["Dscrptn#{i}Txt"]
            {
              description: filing.IRS990PF.parts.pf_part_ixb["Dscrptn#{i}Txt"]
              expenses: formatBigInt(filing.IRS990PF.parts.pf_part_ixb["Expnss#{i}Amt"]) or 0
            }
        otherTotal: formatBigInt filing.IRS990PF.parts.pf_part_ixb?.AllOthrPrgrmRltdInvstTtAmt
        total: formatBigInt filing.IRS990PF.parts.pf_part_ixb?.TtlAmt


      # TODO: could do some activities on whether or not they do political stuff (viia)
    }

  # 990pf
  getFundJson: (fund990, fundPersons, contributions, existing990s) ->
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
      fund.assets = fund990.assets.eoy
      fund.netAssetSales = fund990.netAssets.eoy
      fund.liabilities = fund990.liabilities.eoy

      fund.lastRevenue = fund990.revenue.total
      fund.lastExpenses = fund990.expenses.total
      fund.lastContributionsAndGrants = fund990.expenses.contributionsAndGrants

      fund.applicantInfo = fund990.applicantInfo
      fund.directCharitableActivities = fund990.directCharitableActivities
      fund.programRelatedInvestments = fund990.programRelatedInvestments

    fund

  getFundPersonsJson: (filing) ->
    entityName = getOrgNameByFiling filing

    _.map filing.IRS990PF.groups.PFOffcrDrTrstKyEmpl, (person) ->
      businessName = person.OffcrDrTrstKyEmpl_BsnssNmLn1
      if person.OffcrDrTrstKyEmpl_BsnssNmLn2
        businessName += " #{person.OffcrDrTrstKyEmpl_BsnssNmLn2}"
      {
        name: person.OffcrDrTrstKyEmpl_PrsnNm or businessName
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
        toName: businessName or contribution.GrntOrCntrbtnPdDrYr_RcpntPrsnNm
        toCity: city
        toState: state
        type: type
        toExemptStatus: contribution.GrntOrCntrbtnPdDrYr_RcpntFndtnSttsTxt
        amount: formatBigInt contribution.GrntOrCntrbtnPdDrYr_Amt
        relationship: contribution.GrntOrCntrbtnPdDrYr_RcpntRltnshpTxt
        purpose: contribution.GrntOrCntrbtnPdDrYr_GrntOrCntrbtnPrpsTxt
      }

    await Promise.map contributions, (contribution) ->
      {year, toName, toCity, toState, purpose, amount} = contribution
      einNtee = await getEinNteeFromNameCityState(toName, toCity, toState)
      {ein, nteecc} = einNtee or {}
      contribution = _.defaults {
        toId: ein or toName
      }, contribution
      unless contribution.toId
        console.log 'contribution missing toId', contribution
      if nteecc
        contribution.nteeMajor = nteecc.substr(0, 1)
        contribution.nteeMinor = nteecc.substr(1)

      contribution.hash = md5 [
        year, toName, toCity, toState, purpose, amount
      ].join(':')

      contribution
    , {concurrency: 5}


}
