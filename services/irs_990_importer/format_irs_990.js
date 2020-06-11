import _ from 'lodash'

import { formatInt, formatBigInt, formatWebsite, formatFloat, getOrgNameByFiling } from './helpers.js'

export function getOrg990Json (filing, { ein, year }) {
  const entityName = getOrgNameByFiling(filing)

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
export function getOrgJson (org990, persons, existing990s) {
  const org = {
    // TODO: org type (501..)
    ein: org990.ein,
    name: org990.name,
    city: org990.city,
    state: org990.state,
    website: org990.website,
    mission: org990.mission,
    exemptStatus: org990.exemptStatus
  }

  const maxExistingYear = _.maxBy(existing990s, 'year')?.year
  if ((org990.year >= maxExistingYear) || !maxExistingYear) {
    org.maxYear = org990.year
    org.assets = org990.assets.eoy
    org.netAssets = org990.netAssets.eoy
    org.liabilities = org990.liabilities.eoy
    org.employeeCount = org990.employeeCount
    org.volunteerCount = org990.volunteerCount

    org.lastYearStats = {
      year: org990.year,
      revenue: org990.revenue.total,
      expenses: org990.expenses.total,
      topSalary: _.pick(_.maxBy(persons, 'compensation'), [
        'name', 'title', 'compensation'
      ])
    }
  }

  return org
}

// TODO: mark people from previous years as inactive people for org
export function getOrgPersonsJson (filing) {
  const entityName = getOrgNameByFiling(filing)

  return _.map(filing.IRS990.groups.Frm990PrtVIISctnA, function (person) {
    let businessName = person.BsnssNmLn1Txt
    if (person.BsnssNmLn2Txt) {
      businessName += ` ${person.BsnssNmLn2Txt}`
    }
    return {
      name: person.PrsnNm || businessName,
      entityName,
      entityType: 'org',
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
