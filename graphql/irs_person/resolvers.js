import { GraphqlFormatter } from 'backend-shared'

import IrsPerson from './model.js'

export default {
  Query: {
    irsPersons (rootValue, { ein, query, limit }) {
      if (ein) {
        return IrsPerson.getAllByEin(ein, { limit })
          .then(IrsPerson.groupByYear)
          .then(GraphqlFormatter.fromScylla)
      } else {
        return IrsPerson.search({ query, limit })
          .then(({ rows }) => rows)
          .then(IrsPerson.groupByYear)
          .then(GraphqlFormatter.fromScylla)
      }
    }
  },

  IrsFund: {
    irsPersons (irsFund, { limit }) {
      return IrsPerson.getAllByEin(irsFund.ein)
        .then(IrsPerson.groupByYear)
        .then(GraphqlFormatter.fromScylla)
    }
  },

  IrsOrg: {
    irsPersons (irsOrg, { limit }) {
      return IrsPerson.getAllByEin(irsOrg.ein, { limit })
        .then(IrsPerson.groupByYear)
        .then(GraphqlFormatter.fromScylla)
    }
  }
}
