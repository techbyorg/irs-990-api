let NameCase, SentenceCase;
import router from 'exoid-router';
import { Format } from 'backend-shared';
import { defaultFieldResolver } from 'graphql';
import { SchemaDirectiveVisitor } from 'graphql-tools';

export let nameCase = NameCase = class NameCase extends SchemaDirectiveVisitor {
  visitFieldDefinition(field) {
    const {resolve = defaultFieldResolver} = field;
    field.resolve = function(...args) {
      const str = resolve.apply(this, args);
      return Format.nameCase(str);
    };
    
  }
};

export let sentenceCase = SentenceCase = class SentenceCase extends SchemaDirectiveVisitor {
  visitFieldDefinition(field) {
    const {resolve = defaultFieldResolver} = field;
    field.resolve = function(...args) {
      const str = resolve.apply(this, args);
      return Format.sentenceCase(str);
    };
    
  }
};
