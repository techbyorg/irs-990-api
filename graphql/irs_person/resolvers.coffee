{GraphqlFormatter} = require 'phil-helpers'

IrsPerson = require './model'

module.exports = {
  Query:
    irsPersons: (rootValue, {ein, query}) ->
      if ein
        IrsPerson.getAllByEin ein
        .then GraphqlFormatter.fromScylla
      else
        IrsPerson.search {query}
        .then GraphqlFormatter.fromElasticsearch
}
