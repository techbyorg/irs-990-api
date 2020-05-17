_ = require 'lodash'

{formatInt, formatBigInt, formatWebsite, formatFloat, getOrgNameByFiling} = require './helpers'

module.exports = {
  getOrg990EZJson: (filing) ->
    entityName = getOrgNameByFiling filing

    exemptStatus = if filing.IRS990EZ.parts.ez_part_0?.Orgnztn527Ind \
                   then '527' \
                   else if filing.IRS990EZ.parts.ez_part_0?.Orgnztn49471NtPFInd \
                   then '4947a1' \
                   else if filing.IRS990EZ.parts.ez_part_0?.Orgnztn501c3Ind \
                   then '501c3'
                   # https://github.com/jsfenfen/990-xml-reader/issues/26
                   # else if filing.IRS990EZ.parts.ez_part_0?.Orgnztn501cInd
                   # then "501c#{filing.IRS990EZ.parts.ez_part_0?.Orgnztn501cInd}"

    {
      name: entityName
      city: filing.ReturnHeader.USAddrss_CtyNm
      state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd
      website: formatWebsite filing.IRS990EZ.parts.ez_part_0?.WbstAddrssTxt
      exemptStatus: exemptStatus
      mission: filing.IRS990EZ.parts.ez_part_iii?.PrmryExmptPrpsTxt
      revenue: _.pickBy
        investments: formatBigInt filing.IRS990EZ.parts.ez_part_i?.InvstmntIncmAmt
        grants: formatBigInt filing.IRS990EZ.parts.ez_part_i?.GrntsAndSmlrAmntsPdAmt
        saleOfAssets: formatBigInt filing.IRS990EZ.parts.ez_part_i?.SlOfAsstsGrssAmt # ?
        saleOfInventory: formatBigInt filing.IRS990EZ.parts.ez_part_i?.GrssSlsOfInvntryAmt # ?
        gaming: formatBigInt filing.IRS990EZ.parts.ez_part_i?.GmngGrssIncmAmt
        fundraising: formatBigInt filing.IRS990EZ.parts.ez_part_i?.FndrsngGrssIncmAmt
        # ubi: formatBigInt filing.IRS990EZ.parts.part_i?.TtlGrssUBIAmt # **
        # netUbi: formatBigInt filing.IRS990EZ.parts.part_i?.NtUnrltdBsTxblIncmAmt
        contributionsAndGrants: formatBigInt filing.IRS990EZ.parts.ez_part_i?.CntrbtnsGftsGrntsEtcAmt
        # member dues
        programService: formatBigInt filing.IRS990EZ.parts.ez_part_i?.MmbrshpDsAmt
        other: formatBigInt filing.IRS990EZ.parts.ez_part_i?.OthrRvnTtlAmt
        total: formatBigInt filing.IRS990EZ.parts.ez_part_i?.TtlRvnAmt

      paidBenefitsToMembers: formatBigInt filing.IRS990EZ.parts.ez_part_i?.BnftsPdTOrFrMmbrsAmt
      expenses: _.pickBy
        salaries: formatBigInt filing.IRS990EZ.parts.ez_part_i?.SlrsOthrCmpEmplBnftAmt
        goodsSold: formatBigInt filing.IRS990EZ.parts.ez_part_i?.CstOfGdsSldAmt
        sales: formatBigInt filing.IRS990EZ.parts.ez_part_i?.CstOrOthrBssExpnsSlAmt
        independentContractors: formatBigInt filing.IRS990EZ.parts.ez_part_i?.FsAndOthrPymtTIndCntrctAmt
        rent: formatBigInt filing.IRS990EZ.parts.ez_part_i?.OccpncyRntUtltsAndMntAmt
        printing: formatBigInt filing.IRS990EZ.parts.ez_part_i?.PrntngPblctnsPstgAmt
        specialEvents: formatBigInt filing.IRS990EZ.parts.ez_part_i?.SpclEvntsDrctExpnssAmt
        other: formatBigInt filing.IRS990EZ.parts.ez_part_i?.OthrExpnssTtlAmt
        total: formatBigInt filing.IRS990EZ.parts.ez_part_i?.TtlExpnssAmt # **
        programServicesTotal: formatBigInt filing.IRS990EZ.parts.ez_part_iii?.TtlPrgrmSrvcExpnssAmt
      assets: _.pickBy
        cashBoy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.CshSvngsAndInvstmnts_BOYAmt
        cashEoy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.CshSvngsAndInvstmnts_EOYAmt
        realEstateBoy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.LndAndBldngs_BOYAmt
        realEstateEoy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.LndAndBldngs_EOYAmt
        boy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.Frm990TtlAssts_BOYAmt
        eoy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.Frm990TtlAssts_EOYAmt
      liabilities: _.pickBy
        boy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.SmOfTtlLblts_BOYAmt
        eoy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.SmOfTtlLblts_EOYAmt
      netAssets: _.pickBy
        boy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.NtAsstsOrFndBlncs_BOYAmt
        eoy: formatBigInt filing.IRS990EZ.parts.ez_part_ii?.NtAsstsOrFndBlncs_EOYAmt # **
      #
      # votingMemberCount: filing.IRS990EZ.parts.part_i?.VtngMmbrsGvrnngBdyCnt
      # independentVotingMemberCount: filing.IRS990EZ.parts.part_i?.VtngMmbrsIndpndntCnt
      #
      # employeeCount: filing.IRS990EZ.parts.part_i?.TtlEmplyCnt # **
      # volunteerCount: filing.IRS990EZ.parts.part_i?.TtlVlntrsCnt # **
    }

  getOrgEZPersonsJson: (filing) ->
    entityName = getOrgNameByFiling filing

    persons = filing.IRS990EZ.groups.EZOffcrDrctrTrstEmpl
    if filing.IRS990EZ.groups.EZCmpnstnHghstPdEmpl
      persons.concat filing.IRS990EZ.groups.EZCmpnstnHghstPdEmpl

    persons = _.map persons, (person) ->
      businessName = person.BsnssNmLn1
      if person.BsnssNmLn2
        businessName += " #{person.BsnssNmLn2}"
      {
        name: person.PrsnNm or businessName
        entityName: entityName
        entityType: 'org'
        year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
        isBusiness: Boolean businessName
        title: person.TtlTxt
        weeklyHours: formatFloat person.AvrgHrsPrWkDvtdTPsRt or person.AvrgHrsPrWkRt
        compensation: formatInt person.CmpnstnAmt
        expenseAccount: formatInt person.ExpnsAccntOthrAllwncAmt
        otherCompensation: formatInt person.EmplyBnftPrgrmAmt
      }
    _.uniqBy persons, 'name'

}
