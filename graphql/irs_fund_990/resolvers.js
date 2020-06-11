// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
import { GraphqlFormatter } from 'backend-shared'
import IrsFund990 from './model'

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
