/* eslint-disable
    no-unused-vars,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
import router from 'exoid-router'
import { Format } from 'backend-shared'
import { defaultFieldResolver } from 'graphql'
import { SchemaDirectiveVisitor } from 'graphql-tools'
let NameCase, SentenceCase

export const nameCase = NameCase = class NameCase extends SchemaDirectiveVisitor {
  visitFieldDefinition (field) {
    const { resolve = defaultFieldResolver } = field
    field.resolve = function (...args) {
      const str = resolve.apply(this, args)
      return Format.nameCase(str)
    }
  }
}

export const sentenceCase = SentenceCase = class SentenceCase extends SchemaDirectiveVisitor {
  visitFieldDefinition (field) {
    const { resolve = defaultFieldResolver } = field
    field.resolve = function (...args) {
      const str = resolve.apply(this, args)
      return Format.sentenceCase(str)
    }
  }
}
