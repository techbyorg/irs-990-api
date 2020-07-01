import _ from 'lodash'

import { formatInt, formatBigInt, formatWebsite, formatFloat, getNonprofitNameByFiling } from './helpers.js'

export function getNonprofit990Json (filing, { ein, year }) {
  const entityName = getNonprofitNameByFiling(filing)

  let exemptStatus
  if (filing.IRS990.parts.part_0?.Orgnztn527Ind) {
    exemptStatus = '527'
  } else if (filing.IRS990.parts.part_0?.Orgnztn49471NtPFInd) {
    exemptStatus = '4947a1'
  } else if (filing.IRS990.parts.part_0?.Orgnztn501c3Ind) {
    exemptStatus = '501c3'
  }
  // https://github.com/jsfenfen/990-xml-reader/issues/26
  // else if filing.IRS990EZ.parts.ez_part_0?.Orgnztn501cInd
  // then "501c#{filing.IRS990EZ.parts.ez_part_0?.Orgnztn501cInd}"

  return {
    ein,
    year,
    name: entityName,
    city: filing.ReturnHeader.USAddrss_CtyNm,
    state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd,
    website: formatWebsite(filing.IRS990.parts.part_0?.WbstAddrssTxt),
    exemptStatus,
    mission: filing.IRS990.parts.part_i?.ActvtyOrMssnDsc,
    revenue: _.pickBy({
      investments: formatBigInt(filing.IRS990.parts.part_i?.CYInvstmntIncmAmt),
      grants: formatBigInt(filing.IRS990.parts.part_i?.CYGrntsAndSmlrPdAmt),
      ubi: formatBigInt(filing.IRS990.parts.part_i?.TtlGrssUBIAmt), // **
      netUbi: formatBigInt(filing.IRS990.parts.part_i?.NtUnrltdBsTxblIncmAmt),
      contributionsAndGrants: formatBigInt(filing.IRS990.parts.part_i?.CYCntrbtnsGrntsAmt),
      programService: formatBigInt(filing.IRS990.parts.part_i?.CYPrgrmSrvcRvnAmt),
      other: formatBigInt(filing.IRS990.parts.part_i?.CYOthrRvnAmt),
      total: formatBigInt(filing.IRS990.parts.part_i?.CYTtlRvnAmt)
    }),

    paidBenefitsToMembers: formatBigInt(filing.IRS990.parts.part_i?.CYBnftsPdTMmbrsAmt),
    expenses: _.pickBy({
      salaries: formatBigInt(filing.IRS990.parts.part_i?.CYSlrsCmpEmpBnftPdAmt),
      professionalFundraising: formatBigInt(filing.IRS990.parts.part_i?.CYTtlPrfFndrsngExpnsAmt),
      fundraising: formatBigInt(filing.IRS990.parts.part_i?.CYTtlPrfFndrsngExpnsAmt),
      other: formatBigInt(filing.IRS990.parts.part_i?.CYOthrExpnssAmt),
      total: formatBigInt(filing.IRS990.parts.part_i?.CYTtlExpnssAmt)
    }), // **
    assets: _.pickBy({
      boy: formatBigInt(filing.IRS990.parts.part_i?.TtlAsstsBOYAmt),
      eoy: formatBigInt(filing.IRS990.parts.part_i?.TtlAsstsEOYAmt)
    }),
    liabilities: _.pickBy({
      boy: formatBigInt(filing.IRS990.parts.part_i?.TtlLbltsBOYAmt),
      eoy: formatBigInt(filing.IRS990.parts.part_i?.TtlLbltsEOYAmt)
    }),
    netAssets: _.pickBy({
      boy: formatBigInt(filing.IRS990.parts.part_i?.NtAsstsOrFndBlncsBOYAmt),
      eoy: formatBigInt(filing.IRS990.parts.part_i?.NtAsstsOrFndBlncsEOYAmt)
    }), // **

    votingMemberCount: formatInt(filing.IRS990.parts.part_i?.VtngMmbrsGvrnngBdyCnt),
    independentVotingMemberCount: formatInt(filing.IRS990.parts.part_i?.VtngMmbrsIndpndntCnt),

    employeeCount: formatInt(filing.IRS990.parts.part_i?.TtlEmplyCnt), // **
    volunteerCount: formatInt(filing.IRS990.parts.part_i?.TtlVlntrsCnt) // **
  }
}

// 990ez / 990pf
export function getNonprofitJson (nonprofit990, persons, existing990s) {
  const nonprofit = {
    // TODO: nonprofit type (501..)
    ein: nonprofit990.ein,
    name: nonprofit990.name,
    city: nonprofit990.city,
    state: nonprofit990.state,
    website: nonprofit990.website,
    mission: nonprofit990.mission,
    exemptStatus: nonprofit990.exemptStatus
  }

  const maxExistingYear = _.maxBy(existing990s, 'year')?.year
  if ((nonprofit990.year >= maxExistingYear) || !maxExistingYear) {
    nonprofit.maxYear = nonprofit990.year
    nonprofit.assets = nonprofit990.assets.eoy
    nonprofit.netAssets = nonprofit990.netAssets.eoy
    nonprofit.liabilities = nonprofit990.liabilities.eoy
    nonprofit.employeeCount = nonprofit990.employeeCount
    nonprofit.volunteerCount = nonprofit990.volunteerCount

    nonprofit.lastYearStats = {
      year: nonprofit990.year,
      revenue: nonprofit990.revenue.total,
      expenses: nonprofit990.expenses.total,
      topSalary: _.pick(_.maxBy(persons, 'compensation'), [
        'name', 'title', 'compensation'
      ])
    }
  }

  return nonprofit
}

// TODO: mark people from previous years as inactive people for nonprofit
export function getNonprofitPersonsJson (filing) {
  const entityName = getNonprofitNameByFiling(filing)

  return _.map(filing.IRS990.groups.Frm990PrtVIISctnA, function (person) {
    let businessName = person.BsnssNmLn1Txt
    if (person.BsnssNmLn2Txt) {
      businessName += ` ${person.BsnssNmLn2Txt}`
    }
    return {
      name: person.PrsnNm || businessName,
      entityName,
      entityType: 'nonprofit',
      year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4),
      isBusiness: Boolean(businessName),
      title: person.TtlTxt,
      weeklyHours: formatFloat(person.AvrgHrsPrWkRt || person.AvrgHrsPrWkRltdOrgRt),
      compensation: formatInt(person.RprtblCmpFrmOrgAmt),
      relatedCompensation: formatInt(person.RprtblCmpFrmRltdOrgAmt),
      otherCompensation: formatInt(person.OthrCmpnstnAmt),
      isOfficer: person.OffcrInd === 'X',
      isFormerOfficer: person.FrmrOfcrDrctrTrstInd === 'X',
      isKeyEmployee: person.KyEmplyInd === 'X',
      isHighestPaidEmployee: person.HghstCmpnstdEmplyInd === 'X'
    }
  })
}
