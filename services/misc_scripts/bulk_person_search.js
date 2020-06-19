import _ from 'lodash'
import request from 'request-promise'
import csv from 'csvtojson'
import Promise from 'bluebird'

const NAME_CHUNK_SIZE = 250

csv().fromFile('../../Downloads/Connections.csv')
  .then((linkedInConnections) => {
    const names = _.take(_.map(linkedInConnections, (connection) =>
      `${connection['First Name']} ${connection['Last Name']}`
    ), 300)
    // const names = [
    //   'reid hoffman'
    // ]

    const query = `
      query($query: ESQuery!) {
        irsPersons(query: $query, limit:100) {
          nodes {
            name, 
            irsOrg { name, city, state, assets }, 
            irsFund { name, city, state, assets }
          }
        }
      }
    `

    // ES `should` seems to break at 300+ items
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
      const persons = response.data.irsPersons.nodes
      const groupedPersons = _.groupBy(persons, 'name')
      _.forEach(groupedPersons, (persons) => {
        console.log(persons[0].name)
        console.log('-------------')
        _.forEach(persons, (person) => {
          const entity = person.irsOrg || person.irsFund
          console.log(entity.name, '|', entity.city, entity.state, entity.assets)
        })
        console.log('')
      })
    })
  })
