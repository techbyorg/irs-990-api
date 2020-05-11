_ = require 'lodash'

{formatInt, formatWebsite, formatFloat, getOrgNameByFiling} = require './helpers'
config = require '../../config'

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
      importVersion: config.CURRENT_IMPORT_VERSION
      ein: filing.ReturnHeader.ein
      name: entityName
      city: filing.ReturnHeader.USAddrss_CtyNm
      state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd
      # year: filing.ReturnHeader.RtrnHdr_TxYr
      year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
      objectId: "#{filing.objectId}"
      website: formatWebsite filing.IRS990EZ.parts.ez_part_0?.WbstAddrssTxt
      exemptStatus: exemptStatus
      mission: filing.IRS990EZ.parts.ez_part_iii?.PrmryExmptPrpsTxt
      revenue: _.pickBy
        investments: formatInt filing.IRS990EZ.parts.ez_part_i?.InvstmntIncmAmt
        grants: formatInt filing.IRS990EZ.parts.ez_part_i?.GrntsAndSmlrAmntsPdAmt
        saleOfAssets: formatInt filing.IRS990EZ.parts.ez_part_i?.SlOfAsstsGrssAmt # ?
        saleOfInventory: formatInt filing.IRS990EZ.parts.ez_part_i?.GrssSlsOfInvntryAmt # ?
        gaming: formatInt filing.IRS990EZ.parts.ez_part_i?.GmngGrssIncmAmt
        fundraising: formatInt filing.IRS990EZ.parts.ez_part_i?.FndrsngGrssIncmAmt
        # ubi: formatInt filing.IRS990EZ.parts.part_i?.TtlGrssUBIAmt # **
        # netUbi: formatInt filing.IRS990EZ.parts.part_i?.NtUnrltdBsTxblIncmAmt
        contributionsAndGrants: formatInt filing.IRS990EZ.parts.ez_part_i?.CntrbtnsGftsGrntsEtcAmt
        # member dues
        programService: formatInt filing.IRS990EZ.parts.ez_part_i?.MmbrshpDsAmt
        other: formatInt filing.IRS990EZ.parts.ez_part_i?.OthrRvnTtlAmt
        total: formatInt filing.IRS990EZ.parts.ez_part_i?.TtlRvnAmt

      paidBenefitsToMembers: filing.IRS990EZ.parts.ez_part_i?.BnftsPdTOrFrMmbrsAmt
      expenses: _.pickBy
        salaries: formatInt filing.IRS990EZ.parts.ez_part_i?.SlrsOthrCmpEmplBnftAmt
        goodsSold: formatInt filing.IRS990EZ.parts.ez_part_i?.CstOfGdsSldAmt
        sales: formatInt filing.IRS990EZ.parts.ez_part_i?.CstOrOthrBssExpnsSlAmt
        independentContractors: formatInt filing.IRS990EZ.parts.ez_part_i?.FsAndOthrPymtTIndCntrctAmt
        rent: formatInt filing.IRS990EZ.parts.ez_part_i?.OccpncyRntUtltsAndMntAmt
        printing: formatInt filing.IRS990EZ.parts.ez_part_i?.PrntngPblctnsPstgAmt
        specialEvents: formatInt filing.IRS990EZ.parts.ez_part_i?.SpclEvntsDrctExpnssAmt
        other: formatInt filing.IRS990EZ.parts.ez_part_i?.OthrExpnssTtlAmt
        total: formatInt filing.IRS990EZ.parts.ez_part_i?.TtlExpnssAmt # **
        programServicesTotal: formatInt filing.IRS990EZ.parts.ez_part_iii?.TtlPrgrmSrvcExpnssAmt
      assets: _.pickBy
        cashBoy: formatInt filing.IRS990EZ.parts.ez_part_ii?.CshSvngsAndInvstmnts_BOYAmt
        cashEoy: formatInt filing.IRS990EZ.parts.ez_part_ii?.CshSvngsAndInvstmnts_EOYAmt
        realEstateBoy: formatInt filing.IRS990EZ.parts.ez_part_ii?.LndAndBldngs_BOYAmt
        realEstateEoy: formatInt filing.IRS990EZ.parts.ez_part_ii?.LndAndBldngs_EOYAmt
        boy: formatInt filing.IRS990EZ.parts.ez_part_ii?.Frm990TtlAssts_BOYAmt
        eoy: formatInt filing.IRS990EZ.parts.ez_part_ii?.Frm990TtlAssts_EOYAmt
      liabilities: _.pickBy
        boy: formatInt filing.IRS990EZ.parts.ez_part_ii?.SmOfTtlLblts_BOYAmt
        eoy: formatInt filing.IRS990EZ.parts.ez_part_ii?.SmOfTtlLblts_EOYAmt
      netAssets: _.pickBy
        boy: formatInt filing.IRS990EZ.parts.ez_part_ii?.NtAsstsOrFndBlncs_BOYAmt
        eoy: formatInt filing.IRS990EZ.parts.ez_part_ii?.NtAsstsOrFndBlncs_EOYAmt # **
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
        ein: filing.ReturnHeader.ein
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
