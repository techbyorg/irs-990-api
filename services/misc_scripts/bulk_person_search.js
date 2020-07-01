import _ from 'lodash'
import request from 'request-promise'
import csv from 'csvtojson'
import Promise from 'bluebird'

const NAME_CHUNK_SIZE = 100

csv().fromFile('../../Downloads/Connections.csv')
  .then((linkedInConnections) => {
    const names = _.map(linkedInConnections, (connection) =>
      `${connection['First Name']} ${connection['Last Name']}`
    )
    // const names = [
    //   'reid hoffman'
    // ]

    const query = `
      query($query: ESQuery!) {
        irsPersons(query: $query, limit:10000) {
          nodes {
            name, 
            irsNonprofit { name, city, state, assets }, 
            irsFund { name, city, state, assets }
          }
        }
      }
    `

    // throttle long lists
    const nameChunks = _.chunk(names, NAME_CHUNK_SIZE)

    Promise.each(nameChunks, async (names) => {
      const variables = {
        query: {
          bool: {
            should: _.map(names, (name) => ({ match_phrase: { name } }))
          }
        }
      }

      const response = await request({
        uri: 'https://api.techby.org/990/v1/graphql',
        method: 'post',
        body: { query, variables },
        json: true
      })
      let persons = response.data.irsPersons.nodes
      persons = _.filter(persons, ({ irsNonprofit, irsFund }) => irsNonprofit?.state === 'CA' || irsFund?.state === 'CA')
      const groupedPersons = _.groupBy(persons, 'name')
      _.forEach(groupedPersons, (persons) => {
        console.log(persons[0].name)
        console.log('-------------')
        _.forEach(persons, (person) => {
          const entity = person.irsNonprofit || person.irsFund
          console.log(entity.name, '|', entity.city, entity.state, entity.assets)
        })
        console.log('')
      })
    }).then(() => { console.log('done') })
  })
