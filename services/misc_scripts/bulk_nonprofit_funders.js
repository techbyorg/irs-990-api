// Find fiunders of multiple nonprofits
import _ from 'lodash'

import { sumByLong } from '../irs_990_importer/helpers.js'
import { setup } from '../setup.js'
import IrsContribution from '../../graphql/irs_contribution/model.js'
import IrsFund from '../../graphql/irs_fund/model.js'

// ffwd alumni
const toIds = [
  '842339499', // almost fun
  // couldn't find ample labs
  // couldn't find coachme
  // couldn't find discriminology
  '472676458', // gladeo
  '821011857', // good call
  '831794093', // hikma
  '475324172', // openaq
  // couldn't find quipu
  '813080695', // justfix
  '820670099', // dost
  '474689664', // dreamers roadmap
  '822696116', // empower work
  '462676188', // learning equality
  '814324563', // objective zero
  '822413756', // peerlift
  '831030107', // tarjimly
  '824456163', // upchieve
  '821736267', // upsolve
  '472691544', // we vote
  '364729392', // one degree
  '271275246', // beyond 12
  '811567495', // concrn
  // couldn't find issue voter
  '813042564', // mindright
  // couldn't find online sos
  // couldn't find onward
  '821805718', // raheem ai
  // couldn't find real talk
  '821157215', // think of us
  '464255260', // commonlit
  '371776296', // democracy earth
  '812908499', // hack club
  '812934607', // intelehealth
  '451059457', // learn fresh
  // couldn't find open media project
  '813764408', // we the protesters
  '474300047', // igottamakeit
  '900796160', // careervillage
  '461518188', // feedingforward
  '900514027', // nexleaf
  '454011283', // callisto
  '462736440', // quill
  // couldn't find stellar
  '474616102', // talkingpoints
  '471444637', // watttime
  '275104203', // medic mobile
  '271052771', // moneythink
  '464746592', // noorahealth
  '271103057' // sirum

]

// legal aid groups
// const toIds = [
//   '133505428',
//   '223825867',
//   '202484231',
//   '363863573',
//   '941631316',
//   '954016750',
//   '364348917',
//   '954738518',
//   '311771358',
//   '475278715',
//   '942527939',
//   '475563704',
//   '951684067',
//   '813629630',
//   '260688375'
// ]

const formatNumber = number => Math.round(number).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
setup().then(() => {
  IrsContribution.getAllFromEinsFromToEins(toIds)
    .then(async function (contributions) {
      console.log(contributions)
      const groups = _.groupBy(contributions, 'fromEin')
      console.log(contributions)
      let funders = await (Promise.all(_.map(groups, async function (contributions, ein) {
        const irsFund = await (IrsFund.getByEin(ein))
        return {
          ein,
          name: irsFund.name,
          count: _.uniqBy(contributions, 'toId').length,
          sum: formatNumber(sumByLong(contributions, 'amount'))
        }
      })))

      funders = _.orderBy(funders, 'count', 'desc')

      return _.map(funders, funder => console.log(`${funder.name} (${funder.ein}) donated to ${funder.count} nonprofit(s) a total of $${funder.sum}`))
    })
})
