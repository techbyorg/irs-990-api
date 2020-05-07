request = require 'request-promise'
requestNonPromise = require 'request'
exec = require('child_process').exec
csv = require 'csvtojson'
normalizeUrl = require 'normalize-url'
Promise = require 'bluebird'
fs = require 'fs'
stringSimilarity = require 'string-similarity'
cheerio = require 'cheerio'
_ = require 'lodash'

IrsContribution = require '../graphql/irs_contribution/model'
IrsFund = require '../graphql/irs_fund/model'
IrsFund990 = require '../graphql/irs_fund_990/model'
IrsOrg = require '../graphql/irs_org/model'
IrsOrg990 = require '../graphql/irs_org_990/model'
IrsPerson = require '../graphql/irs_person/model'
JobCreateService = require '../services/job_create'
CacheService = require '../services/cache'
config = require '../config'

FIVE_MB = 5 * 1024 * 1024

formatInt = (int) -> if int? then parseInt(int) else null
formatFloat = (float) -> if float? then parseFloat(float) else null
formatWebsite = (website) ->
  if website and website isnt 'N/A'
    try
      website = normalizeUrl website
    catch err
      null
  website
getOrgNameByFiling = (filing) ->
  entityName = filing.ReturnHeader.BsnssNm_BsnssNmLn1Txt
  if filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt
    entityName += " #{filing.ReturnHeader.BsnssNm_BsnssNmLn2Txt}"
  entityName

class Irs990Service
  getIndexJson: (year) ->
    indexUrl = "https://s3.amazonaws.com/irs-form-990/index_#{year}.json"
    request indexUrl

  syncYear: (year) =>
    (if year
      @getIndexJson year
    else
      Promise.resolve require('../data/sample_index.json')
    )
    .then (index) ->
      console.log 'got index'
      if year # sample_index is already parsed
        index = JSON.parse index
      else
        year = 2016 # for sample
      console.log 'keys', _.keys(index)
      filings = index["Filings#{year}"]
      console.log filings.length
      chunks = _.chunk filings, 100
      Promise.map chunks, (chunk, i) ->
        console.log i * 100
        funds = _.filter chunk, {FormType: '990PF'}
        console.log 'funds', funds.length
        orgs = _.filter chunk, ({FormType}) -> FormType isnt '990PF'
        console.log 'orgs', orgs.length
        Promise.all _.filter [
          if funds.length
            console.log 'batch', _.map funds, (filing) ->
              {
                ein: filing.EIN
                name: filing.OrganizationName
              }
            IrsFund.batchUpsert _.map funds, (filing) ->
              {
                ein: filing.EIN
                name: filing.OrganizationName
              }
          if funds.length
            IrsFund990.batchUpsert _.map funds, (filing) ->
              {
                ein: filing.EIN
                year: filing.TaxPeriod.substr(0, 4)
                objectId: filing.ObjectId
                type: filing.FormType
                xmlUrl: filing.URL
              }

          if orgs.length
            IrsOrg.batchUpsert _.map orgs, (filing) ->
              {
                ein: filing.EIN
                name: filing.OrganizationName
              }
          if orgs.length
            IrsOrg990.batchUpsert _.map orgs, (filing) ->
              {
                ein: filing.EIN
                year: filing.TaxPeriod.substr(0, 4)
                objectId: filing.ObjectId
                type: filing.FormType
                xmlUrl: filing.URL
            }
        ]
      , {concurrency: 10}


      # Promise.map filings, (filing) ->
      #   i += 1
      #   if not (i % 100)
      #     console.log i
      #   if filing.FormType is '990PF'
      #     Promise.all [
      #       IrsFund.upsert {
      #         ein: filing.EIN
      #         name: filing.OrganizationName
      #       }
      #       IrsFund990.upsert {
      #         ein: filing.EIN
      #         year: filing.TaxPeriod.substr(0, 4)
      #         objectId: filing.ObjectId
      #         type: filing.FormType
      #         xmlUrl: filing.URL
      #       }
      #     ]
      #   else
      #     Promise.all [
      #       IrsOrg.upsert {
      #         ein: filing.EIN
      #         name: filing.OrganizationName
      #       }
      #       IrsOrg990.upsert {
      #         ein: filing.EIN
      #         year: filing.TaxPeriod.substr(0, 4)
      #         objectId: filing.ObjectId
      #         type: filing.FormType
      #         xmlUrl: filing.URL
      #       }
      #     ]
      # , {concurrency: 100}

  ######
  # ORGS
  ######

  getOrg990EZJson: (filing) ->
    website = formatWebsite filing.IRS990EZ.parts.ez_part_0?.WbstAddrssTxt

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
      isProcessed: true
      ein: filing.ReturnHeader.ein
      name: entityName
      city: filing.ReturnHeader.USAddrss_CtyNm
      state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd
      # year: filing.ReturnHeader.RtrnHdr_TxYr
      year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
      objectId: "#{filing.objectId}"
      website: website
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

  getOrg990Json: (filing) ->
    website = formatWebsite filing.IRS990.parts.part_0?.WbstAddrssTxt

    entityName = getOrgNameByFiling filing

    exemptStatus = if filing.IRS990.parts.part_0?.Orgnztn527Ind \
                   then '527' \
                   else if filing.IRS990.parts.part_0?.Orgnztn49471NtPFInd \
                   then '4947a1' \
                   else if filing.IRS990.parts.part_0?.Orgnztn501c3Ind \
                   then '501c3'
                   # https://github.com/jsfenfen/990-xml-reader/issues/26
                   # else if filing.IRS990EZ.parts.ez_part_0?.Orgnztn501cInd
                   # then "501c#{filing.IRS990EZ.parts.ez_part_0?.Orgnztn501cInd}"

    {
      isProcessed: true
      ein: filing.ReturnHeader.ein
      name: entityName
      city: filing.ReturnHeader.USAddrss_CtyNm
      state: filing.ReturnHeader.USAddrss_SttAbbrvtnCd
      # year: filing.ReturnHeader.RtrnHdr_TxYr
      year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
      objectId: "#{filing.objectId}"
      exemptStatus: exemptStatus
      mission: filing.IRS990.parts.part_i?.ActvtyOrMssnDsc
      website: website
      revenue: _.pickBy
        investments: formatInt filing.IRS990.parts.part_i?.CYInvstmntIncmAmt
        grants: formatInt filing.IRS990.parts.part_i?.CYGrntsAndSmlrPdAmt
        ubi: formatInt filing.IRS990.parts.part_i?.TtlGrssUBIAmt # **
        netUbi: formatInt filing.IRS990.parts.part_i?.NtUnrltdBsTxblIncmAmt
        contributionsAndGrants: formatInt filing.IRS990.parts.part_i?.CYCntrbtnsGrntsAmt
        programService: formatInt filing.IRS990.parts.part_i?.CYPrgrmSrvcRvnAmt
        other: formatInt filing.IRS990.parts.part_i?.CYOthrRvnAmt
        total: formatInt filing.IRS990.parts.part_i?.CYTtlRvnAmt

      paidBenefitsToMembers: formatInt filing.IRS990.parts.part_i?.CYBnftsPdTMmbrsAmt
      expenses: _.pickBy
        salaries: formatInt filing.IRS990.parts.part_i?.CYSlrsCmpEmpBnftPdAmt
        professionalFundraising: formatInt filing.IRS990.parts.part_i?.CYTtlPrfFndrsngExpnsAmt
        fundraising: formatInt filing.IRS990.parts.part_i?.CYTtlPrfFndrsngExpnsAmt
        other: formatInt filing.IRS990.parts.part_i?.CYOthrExpnssAmt
        total: formatInt filing.IRS990.parts.part_i?.CYTtlExpnssAmt # **
      assets: _.pickBy
        boy: formatInt filing.IRS990.parts.part_i?.TtlAsstsBOYAmt
        eoy: formatInt filing.IRS990.parts.part_i?.TtlAsstsEOYAmt
      liabilities: _.pickBy
        boy: formatInt filing.IRS990.parts.part_i?.TtlLbltsBOYAmt
        eoy: formatInt filing.IRS990.parts.part_i?.TtlLbltsEOYAmt
      netAssets: _.pickBy
        boy: formatInt filing.IRS990.parts.part_i?.NtAsstsOrFndBlncsBOYAmt
        eoy: formatInt filing.IRS990.parts.part_i?.NtAsstsOrFndBlncsEOYAmt # **

      votingMemberCount: formatInt filing.IRS990.parts.part_i?.VtngMmbrsGvrnngBdyCnt
      independentVotingMemberCount: formatInt filing.IRS990.parts.part_i?.VtngMmbrsIndpndntCnt

      employeeCount: formatInt filing.IRS990.parts.part_i?.TtlEmplyCnt # **
      volunteerCount: formatInt filing.IRS990.parts.part_i?.TtlVlntrsCnt # **
    }

  # 990ez / 990pf
  getOrgJson: (org990, persons, existing990s) ->
    org = {
      # TODO: org type (501..)
      ein: org990.ein
      name: org990.name
      city: org990.city
      state: org990.state
      website: org990.website
      mission: org990.mission
      exemptStatus: org990.exemptStatus
    }

    maxExistingYear = _.maxBy(existing990s, 'year')?.year
    if org990.year >= maxExistingYear or not maxExistingYear
      org.maxYear = org990.year
      org.assets = org990.assets.eoy
      org.liabilities = org990.liabilities.eoy
      org.lastRevenue = org990.revenue.total
      org.lastExpenses = org990.expenses.total
      org.topSalary = _.pick _.maxBy(persons, 'compensation'), [
        'name', 'title', 'compensation'
      ]

    org


  # TODO: mark people from previous years as inactive people for org
  getOrgPersonsJson: (filing) ->
    entityName = getOrgNameByFiling filing

    _.map filing.IRS990.groups.Frm990PrtVIISctnA, (person) ->
      businessName = person.BsnssNmLn1Txt
      if person.BsnssNmLn2Txt
        businessName += " #{person.BsnssNmLn2Txt}"
      {
        name: person.PrsnNm or businessName
        ein: filing.ReturnHeader.ein
        entityName: entityName
        entityType: 'org'
        year: filing.ReturnHeader.RtrnHdr_TxPrdEndDt.substr(0, 4)
        isBusiness: Boolean businessName
        title: person.TtlTxt
        weeklyHours: formatFloat person.AvrgHrsPrWkRt or person.AvrgHrsPrWkRltdOrgRt
        compensation: formatInt person.RprtblCmpFrmOrgAmt
        relatedCompensation: formatInt person.RprtblCmpFrmRltdOrgAmt
        otherCompensation: formatInt person.OthrCmpnstnAmt
        isOfficer: person.OffcrInd is 'X'
        isFormerOfficer: person.FrmrOfcrDrctrTrstInd is 'X'
        isKeyEmployee: person.KyEmplyInd is 'X'
        isHighestPaidEmployee: person.HghstCmpnstdEmplyInd is 'X'
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

  processOrgFiling: (filing) =>
    IrsOrg990.getAllByEin filing.ReturnHeader.ein
    .then (existing990s) =>
      org990 = @getOrg990Json filing
      orgPersons = @getOrgPersonsJson filing
      # console.log orgPersons
      {
        org990: org990
        persons: orgPersons
        org: @getOrgJson org990, orgPersons, existing990s
      }

  processOrgEZFiling: (filing) =>
    IrsOrg990.getAllByEin filing.ReturnHeader.ein
    .then (existing990s) =>
      org990 = @getOrg990EZJson filing
      orgPersons = @getOrgEZPersonsJson filing
      {
        org990: org990
        persons: orgPersons
        org: @getOrgJson org990, orgPersons, existing990s
      }

  ########
  # FUNDS
  ########

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

  getEinNteeFromNameCityState: (name, city, state) ->
    name = name?.toLowerCase() or ''
    city = city?.toLowerCase() or ''
    state = state?.toLowerCase() or ''
    key = "#{CacheService.PREFIXES.EIN_FROM_NAME}:#{name}:#{city}:#{state}"
    CacheService.preferCache key, ->
      IrsOrg.search {
        limit: 1
        query:
          multi_match:
            query: name
            type: 'bool_prefix'
            fields: ['name', 'name._2gram']
      }
      .then (orgs) ->
        closeEnough = _.filter _.map orgs.rows, (org) ->
          unless org.name
            return 0
          score = stringSimilarity.compareTwoStrings(org.name.toLowerCase(), name)
          # console.log score
          if score > 0.7
            _.defaults {score}, org
        cityMatches = _.filter _.map closeEnough, (org) ->
          unless org.city
            return 0
          if city
            cityScore = stringSimilarity.compareTwoStrings(org.city.toLowerCase(), city)
          else
            cityScore = 1
          if cityScore > 0.8
            _.defaults {cityScore: city}, org

        match = _.maxBy cityMatches, ({score, cityScore}) -> "#{cityScore}|#{score}"
        unless match
          match = _.maxBy closeEnough, 'score'

        if match
          {
            ein: match?.ein
            nteecc: match?.nteecc
          }
        else
          null
        # TODO: can also look at grant amount and income to help find best match
    , {expireSeconds: 1}# FIXME 3600 * 24}

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
    Promise.map contributions, (contribution) =>
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

  processFundFiling: (filing) =>
    IrsFund990.getAllByEin filing.ReturnHeader.ein
    .then (existing990s) =>
      fund990 = @getFund990Json filing
      fundPersons = @getFundPersonsJson filing
      fund = @getFundJson fund990, fundPersons, existing990s

      @getContributionsJson filing
      .then (contributions) ->
        {
          fund: fund
          persons: fundPersons
          fund990: fund990
          contributions: contributions
        }

  upsertOrgs: ({orgs, i}) ->
    # console.log 'upsert', orgs
    IrsOrg.batchUpsert orgs
    .then ->
      console.log 'upserted', i

  syncNtee: ->
    console.log 'sync'
    cache = null
    requestNonPromise('https://nccs-data.urban.org/data/bmf/2019/bmf.bm1908.csv')
    .pipe(fs.createWriteStream('data.csv'))
    .on 'finish', ->
      console.log 'file downloaded'
      chunk = []
      i = 0
      csv().fromFile('data.csv')
      .subscribe ((json) ->
        i += 1
        if i and not (i % 100)
          console.log i
          cache = chunk
          chunk = []
          JobCreateService.createJob {
            queueKey: 'DEFAULT'
            waitForCompletion: true
            job: {orgs: cache, i}
            type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_UPSERT_ORGS
            ttlMs: 60000
            priority: JobCreateService.PRIORITIES.NORMAL
          }
          .catch (err) ->
            console.log 'err', err
        # console.log json
        chunk.push {
          ein: json.EIN
          name: json.NAME
          city: json.CITY
          state: json.STATE
          nteecc: json.NTEECC
        }
      ), (-> console.log 'error'), ->
        console.log 'done'
        IrsOrg.batchUpsert cache

  getFilingJsonFromObjectId: (objectId) ->
    new Promise (resolve, reject) =>
      exec "irsx #{objectId}", {maxBuffer: FIVE_MB}, (err, stdout, stderr) ->
        if err
          reject err
        resolve stdout or stderr
    .then (jsonStr) =>
      filing = try
        JSON.parse jsonStr
      catch err
        # console.log jsonStr
        throw new Error 'json parse fail'

      formattedFiling = _.reduce filing, (obj, part) ->
        if part.schedule_name is 'ReturnHeader990x'
          obj.ReturnHeader = part.schedule_parts.returnheader990x_part_i
        else if part.schedule_name
          obj[part.schedule_name] = {
            parts: part.schedule_parts
            groups: part.groups
          }
        obj
      , {}
      formattedFiling.objectId = objectId

      return formattedFiling


  processOrgChunk: ({chunk}) =>
    Promise.map chunk, (org) =>
      @getFilingJsonFromObjectId org.objectId
      .catch (err) ->
        console.log 'json parse fail'
        IrsOrg990.upsertByRow org, {isProcessed: true}
        .then ->
          throw 'skip'
      .then (filing) =>
        (if filing.IRS990
          @processOrgFiling filing
        else
          @processOrgEZFiling filing)
      .catch (err) ->
        console.log 'caught', err
        {}
    .then (filingResults) ->
      orgs = _.filter _.map filingResults, 'org'
      org990s = _.filter _.map filingResults, 'org990'
      persons = _.filter _.flatten _.map filingResults, 'persons'

      # console.log {orgs, org990s, persons}
      console.log 'orgs', orgs.length, 'org990s', org990s.length, 'persons', persons.length

      Promise.all _.filter [
        if orgs.length
          IrsOrg.batchUpsert orgs
        if org990s.length
          IrsOrg990.batchUpsert org990s, {ESRefresh: true} # so when we fetch isProcessed again, it's accurate
        if persons.length
          IrsPerson.batchUpsert persons
      ]

  processFundChunk: ({chunk}) =>
    Promise.map chunk, (fund) =>
      @getFilingJsonFromObjectId fund.objectId
      .catch (err) ->
        console.log 'json parse fail'
        IrsFund990.upsertByRow fund, {isProcessed: true}
        .then ->
          throw 'skip'
      .then (filing) =>
        @processFundFiling filing
      .catch (err) ->
        console.log 'caught', err
        {}
    .then (filingResults) ->
      funds = _.filter _.map filingResults, 'fund'
      fund990s = _.filter _.map filingResults, 'fund990'
      persons = _.filter _.flatten _.map filingResults, 'persons'
      contributions = _.filter _.flatten _.map filingResults, 'contributions'

      # console.log {funds, fund990s, persons}
      console.log 'funds', funds.length, 'fund990s', fund990s.length, 'persons', persons.length, 'contributions', contributions.length
      # console.log _.map contributions, (c) -> _.pick c, ['toId', 'toName', 'nteeMajor', 'nteeMinor']

      Promise.all _.filter [
        if funds.length
          IrsFund.batchUpsert funds
        if fund990s.length
          IrsFund990.batchUpsert fund990s, {ESRefresh: true} # so when we fetch isProcessed again, it's accurate
        if persons.length
          IrsPerson.batchUpsert persons
        if contributions.length
          IrsContribution.batchUpsert contributions
      ]

  processUnprocessedOrgs: =>
    start = Date.now()
    IrsOrg990.search {
      trackTotalHits: true
      limit: 160 # 16 cpus, 16 chunks
      query:
        bool:
          must:
            term:
              isProcessed: false
    }
    .then (orgs) =>
      console.log orgs.total, 'time', Date.now() - start
      # return
      # TODO: chunk + batchUpsert
      chunks = _.chunk orgs.rows, 10
      Promise.map chunks, (chunk) =>
        JobCreateService.createJob {
          queueKey: 'DEFAULT'
          waitForCompletion: true
          job: {chunk}
          type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PROCESS_ORG_CHUNK
          ttlMs: 60000
          priority: JobCreateService.PRIORITIES.NORMAL
        }
        .catch (err) ->
          console.log 'err', err
      .then =>
        if orgs.total
          console.log 'done step'
          @processUnprocessedOrgs()
        else
          console.log 'done'

      # Promise.map orgs.rows, (org) =>
      #   JobCreateService.createJob {
      #     queueKey: 'DEFAULT'
      #     waitForCompletion: true
      #     job: {original: org, type: 'org'}
      #     type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PROCESS_OBJECT_ID
      #     ttlMs: 20000
      #     priority: JobCreateService.PRIORITIES.NORMAL
      #   }
      #   .catch (err) ->
      #     console.log 'err', err, org.objectId
      # # , {concurrency: 20}
      # .then =>
      #   if orgs.total
      #     console.log 'done step'
      #     @processUnprocessedOrgs()
      #   else
      #     console.log 'done'


  processUnprocessedFunds: =>
    start = Date.now()
    IrsFund990.search {
      trackTotalHits: true
      limit: 80 # 16 cpus, 16 chunks
      query:
        bool:
          must:
            term:
              isProcessed: false
    }
    .then (funds) =>
      console.log funds.total, 'time', Date.now() - start

      # TODO: chunk + batchUpsert
      chunks = _.chunk funds.rows, 5
      Promise.map chunks, (chunk) =>
        JobCreateService.createJob {
          queueKey: 'DEFAULT'
          waitForCompletion: true
          job: {chunk}
          type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PROCESS_FUND_CHUNK
          ttlMs: 60000
          priority: JobCreateService.PRIORITIES.NORMAL
        }
        .catch (err) ->
          console.log 'err', err
      .then =>
        if funds.total
          console.log 'done step'
          @processUnprocessedFunds()
        else
          console.log 'done'

  # TODO: rm
  setLastYearContributions: ->
    IrsFund.search {
      trackTotalHits: true
      limit: 10000
      query:
        bool:
          must_not:
            exists:
              field: 'lastContributions'
    }
    .then ({total, rows}) ->
      console.log total
      Promise.map rows, (row, i) ->
        console.log i
        IrsContribution.getByAllByFromEin row.ein
        .then (contributions) ->
          # console.log contributions
          recentYear = _.maxBy(contributions, 'year')?.year
          if recentYear
            contributions = _.filter contributions, {year: recentYear}
            amount = _.sumBy contributions, ({amount}) -> parseInt amount
          amount ?= 0
          # console.log amount
          IrsFund.upsertByRow row, {lastContributions: amount}

      , {concurrency: 10}


  parseWebsite: ({ein, counter}) ->
    IrsOrg.getByEin ein
    .then (irsOrg) ->
      request {
        uri: irsOrg.website
        headers:
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36'
      }
      .then (html) ->
        $ = cheerio.load html
        text = $.text().toLowerCase()
        text = text.replace /\s+/g, ' '
        console.log 'upsert', text.length
        IrsOrg.upsertByRow irsOrg, {
          websiteText: text.substr(0, 10000)
        }
      .catch (err) ->
        console.log 'website err', irsOrg.website
      .then ->
        console.log counter

  parseGrantMakingWebsites: =>
    IrsOrg.search {
      trackTotalHits: true
      limit: 10000
      # limit: 10
      query:
        bool:
          must: [
            {
              match_phrase_prefix:
                website: 'http'
            }
            {
              match_phrase_prefix:
                nteecc: 'T'
            }
            {
              range:
                lastRevenue:
                  gte: 100000
            }
            {
              range:
                lastExpenses:
                  gte: 100000
            }
          ]
    }
    .then ({total, rows}) ->
      console.log rows.length
      # console.log JSON.stringify(_.map rows, 'name')
      fixed = _.map rows, (row) ->
        row.website = row.website.replace 'https://https', 'https://'
        row.website = row.website.replace 'http://https', 'https://'
        row.website = row.website.replace 'http://http', 'http://'
        row
      valid = _.filter fixed, ({website}) ->
        website.match(/^((https?|ftp|smtp):\/\/)?(www.)?[a-z0-9]+\.[a-z]+(\/[a-zA-Z0-9#]+\/?)*$/)
      # valid = _.take valid, 10
      _.map valid, ({ein}, i) ->
        JobCreateService.createJob {
          queueKey: 'DEFAULT'
          waitForCompletion: false
          job: {ein, counter: i}
          type: JobCreateService.JOB_TYPES.DEFAULT.IRS_990_PARSE_WEBSITE
          ttlMs: 60000
          priority: JobCreateService.PRIORITIES.NORMAL
        }
        .catch (err) ->
          console.log 'err', err


module.exports = new Irs990Service()

###
truncate irs_990_api.irs_orgs_by_ein
truncate irs_990_api.irs_orgs_990_by_ein_and_year
curl -XDELETE http://10.245.244.135:9200/irs_org_990s*
curl -XDELETE http://10.245.244.135:9200/irs_orgs*
curl -XDELETE http://10.245.244.135:9200/irs_fund_990s*
curl -XDELETE http://10.245.244.135:9200/irs_funds*
###
# module.exports.setLastYearContributions()
# module.exports.getEinFromNameCityState 'confett Foundation', 'denver', 'co'
