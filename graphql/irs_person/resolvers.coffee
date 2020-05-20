{GraphqlFormatter} = require 'phil-helpers'

IrsPerson = require './model'

module.exports = {
  Query:
    irsPersons: (rootValue, {ein, query, limit}) ->
      if ein
        IrsPerson.getAllByEin ein, {limit}
        .then GraphqlFormatter.fromScylla
      else
        IrsPerson.search {query, limit}
        .then GraphqlFormatter.fromElasticsearch

  IrsFund:
    irsPersons: (irsFund, {limit}) ->
      IrsPerson.getAllByEin irsFund.ein
      .then GraphqlFormatter.fromScylla

  IrsOrg:
    irsPersons: (irsOrg, {limit}) ->
      IrsPerson.getAllByEin irsOrg.ein, {limit}
      .then GraphqlFormatter.fromScylla
}
