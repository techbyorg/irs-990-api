import _ from 'lodash'
import { Base, cknex } from 'backend-shared'

class IrsPersonModel extends Base {
  getScyllaTables () {
    return [
      {
        name: 'irs_persons_by_ein_and_year_and_name',
        keyspace: 'irs_990_api',
        fields: {
          ein: 'text',
          entityName: 'text',
          entityType: 'text',
          year: 'int',
          name: 'text',
          title: 'text',
          compensation: 'int',
          relatedCompensation: 'int',
          otherCompensation: 'int',
          benefits: 'int',
          weeklyHours: 'int',
          isOfficer: { type: 'boolean', defaultFn () { return false } },
          isFormerOfficer: { type: 'boolean', defaultFn () { return false } },
          isKeyEmployee: { type: 'boolean', defaultFn () { return false } },
          isHighestPaidEmployee: { type: 'boolean', defaultFn () { return false } },
          isBusiness: { type: 'boolean', defaultFn () { return false } }
        },
        primaryKey: {
          partitionKey: ['ein'],
          clusteringColumns: ['name', 'year']
        }
        // could do a materialized view on [[ein], [year, name]], but
        // #s are small enough that server-side ordering should be fine...
      }
    ]
  }

  getElasticSearchIndices () {
    return [
      {
        name: 'irs_persons',
        mappings: {
          ein: { type: 'keyword' },
          entityName: { type: 'text' },
          entityType: { type: 'text' },
          year: { type: 'integer' },
          name: { type: 'search_as_you_type' },
          title: { type: 'text' },
          compensation: { type: 'integer' },
          weeklyHours: { type: 'scaled_float', scaling_factor: 10 },
          isOfficer: { type: 'boolean' },
          isFormerOfficer: { type: 'boolean' },
          isKeyEmployee: { type: 'boolean' },
          isHighestPaidEmployee: { type: 'boolean' },
          isBusiness: { type: 'boolean' }
        }
      }
    ]
  }

  getAllByEin (ein) {
    return cknex().select('*')
      .from('irs_persons_by_ein_and_year_and_name')
      .where('ein', '=', ein)
      .run()
      .map(this.defaultOutput)
  }

  groupByYear (persons) {
    const groupedPersons = _.groupBy(persons, ({ name, ein }) =>
      `${name.toLowerCase()}:${ein}`
    )
    const baseFields = ['ein', 'name', 'entityName', 'entityType']
    persons = _.map(groupedPersons, (persons) => {
      const base = _.pick(persons[0], baseFields)
      const years = _.map(persons, (person) => _.omit(person, baseFields))
      const maxYear = _.maxBy(years, 'year').year
      return _.defaults({ maxYear, years }, base)
    })

    return _.orderBy(persons, 'maxYear', 'desc')
  }
}

export default new IrsPersonModel()
