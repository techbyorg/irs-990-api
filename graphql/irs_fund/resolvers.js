import _ from 'lodash';
import { cknex, GraphqlFormatter } from 'backend-shared';
import IrsFundModel from './model';
import IrsFund990 from '../irs_fund_990/model';
import IrsContribution from '../irs_contribution/model';

export let Query = {
  irsFund(rootValue, {ein}) {
    return IrsFundModel.getByEin(ein);
  },

  irsFunds(rootValue, {query, sort, limit}) {
    return IrsFundModel.search({query, sort, limit})
    .then(GraphqlFormatter.fromElasticsearch);
  }
};

export let IrsFund = {
  async yearlyStats(irsFund) {
    let irs990s = await IrsFund990.getAllByEin(irsFund.ein);
    irs990s = _.orderBy(irs990s, 'year');
    return {
      years: _.map(irs990s, irs990 => ({
        year: irs990.year,
        assets: irs990.assets?.eoy,
        grantSum: irs990.expenses?.contributionsAndGrants,
        officerSalaries: irs990.expenses?.officerSalaries
      }))
    };
  }
};
