_ = require 'lodash'
{Base, cknex, elasticsearch} = require 'backend-shared'

config = require '../../config'

class IrsPersonModel extends Base
  getScyllaTables: ->
    [
      {
        name: 'irs_persons_by_ein_and_year_and_name'
        keyspace: 'irs_990_api'
        fields:
          ein: 'text'
          entityName: 'text'
          entityType: 'text'
          year: 'int'
          name: 'text'
          title: 'text'
          compensation: 'int'
          relatedCompensation: 'int'
          otherCompensation: 'int'
          benefits: 'int'
          weeklyHours: 'int'
          isOfficer: {type: 'boolean', defaultFn: -> false}
          isFormerOfficer: {type: 'boolean', defaultFn: -> false}
          isKeyEmployee: {type: 'boolean', defaultFn: -> false}
          isHighestPaidEmployee: {type: 'boolean', defaultFn: -> false}
          isBusiness: {type: 'boolean', defaultFn: -> false}
        primaryKey:
          partitionKey: ['ein']
          clusteringColumns: ['name', 'year']
        # could do a materialized view on [[ein], [year, name]], but
        # #s are small enough that server-side ordering should be fine...
      }
    ]

  getElasticSearchIndices: ->
    [
      {
        name: 'irs_persons'
        mappings:
          ein: {type: 'keyword'}
          entityName: {type: 'text'}
          entityType: {type: 'text'}
          year: {type: 'integer'}
          name: {type: 'search_as_you_type'}
          title: {type: 'text'}
          compensation: {type: 'integer'}
          weeklyHours: {type: 'scaled_float', scaling_factor: 10}
          isOfficer: {type: 'boolean'}
          isFormerOfficer: {type: 'boolean'}
          isKeyEmployee: {type: 'boolean'}
          isHighestPaidEmployee: {type: 'boolean'}
          isBusiness: {type: 'boolean'}
      }
    ]

  getAllByEin: (ein) =>
    cknex().select '*'
    .from 'irs_persons_by_ein_and_year_and_name'
    .where 'ein', '=', ein
    .run()
    .map @defaultOutput

  groupByYear: (persons) ->
    groupedPersons = _.groupBy persons, 'name'
    baseFields = ['ein', 'name', 'entityName', 'entityType']
    persons = _.map groupedPersons, (persons) ->
      base = _.pick persons[0], baseFields
      years = _.map persons, (person) ->
        _.omit person, baseFields
      maxYear = _.maxBy(years, 'year').year
      _.defaults {maxYear, years}, base

    _.orderBy persons, 'maxYear', 'desc'

module.exports = new IrsPersonModel()
