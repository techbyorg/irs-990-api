{GraphqlFormatter} = require 'backend-shared'

IrsPerson = require './model'

module.exports = {
  Query:
    irsPersons: (rootValue, {ein, query, limit}) ->
      if ein
        IrsPerson.getAllByEin ein, {limit}
        .then IrsPerson.groupByYear
        .then GraphqlFormatter.fromScylla
      else
        IrsPerson.search {query, limit}
        .then IrsPerson.groupByYear
        .then GraphqlFormatter.fromElasticsearch

  IrsFund:
    irsPersons: (irsFund, {limit}) ->
      IrsPerson.getAllByEin irsFund.ein
      .then IrsPerson.groupByYear
      .then GraphqlFormatter.fromScylla

  IrsOrg:
    irsPersons: (irsOrg, {limit}) ->
      IrsPerson.getAllByEin irsOrg.ein, {limit}
      .then IrsPerson.groupByYear
      .then GraphqlFormatter.fromScylla
}
