import { GraphqlFormatter } from 'backend-shared';
import IrsPerson from './model';

export let Query = {
  irsPersons(rootValue, {ein, query, limit}) {
    if (ein) {
      return IrsPerson.getAllByEin(ein, {limit})
      .then(IrsPerson.groupByYear)
      .then(GraphqlFormatter.fromScylla);
    } else {
      return IrsPerson.search({query, limit})
      .then(IrsPerson.groupByYear)
      .then(GraphqlFormatter.fromElasticsearch);
    }
  }
};

export let IrsFund = {
  irsPersons(irsFund, {limit}) {
    return IrsPerson.getAllByEin(irsFund.ein)
    .then(IrsPerson.groupByYear)
    .then(GraphqlFormatter.fromScylla);
  }
};

export let IrsOrg = {
  irsPersons(irsOrg, {limit}) {
    return IrsPerson.getAllByEin(irsOrg.ein, {limit})
    .then(IrsPerson.groupByYear)
    .then(GraphqlFormatter.fromScylla);
  }
};
