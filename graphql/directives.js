import { Format } from 'backend-shared'
import { defaultFieldResolver } from 'graphql'
import { SchemaDirectiveVisitor } from 'graphql-tools'

export const nameCase = class NameCase extends SchemaDirectiveVisitor {
  visitFieldDefinition (field) {
    const { resolve = defaultFieldResolver } = field
    field.resolve = function (...args) {
      const str = resolve.apply(this, args)
      return Format.nameCase(str)
    }
  }
}

export const sentenceCase = class SentenceCase extends SchemaDirectiveVisitor {
  visitFieldDefinition (field) {
    const { resolve = defaultFieldResolver } = field
    field.resolve = function (...args) {
      const str = resolve.apply(this, args)
      return Format.sentenceCase(str)
    }
  }
}
