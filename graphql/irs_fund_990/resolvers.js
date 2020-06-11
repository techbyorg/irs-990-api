import { GraphqlFormatter } from 'backend-shared'

import IrsFund990 from './model.js'

export const Query = {
  irsFund990s (_, { ein, limit }) {
    return IrsFund990.getAllByEin(ein, { limit })
      .then(GraphqlFormatter.fromScylla)
  }
}

export const IrsFund = {
  irsFund990s (irsFund, { limit }) {
    return IrsFund990.getAllByEin(irsFund.ein, { limit })
      .then(GraphqlFormatter.fromScylla)
  }
}
