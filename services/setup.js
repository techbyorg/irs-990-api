import fs from 'fs';
import path from 'path';
import _ from 'lodash';
import Promise from 'bluebird';
import { cknex, ElasticsearchSetup, JobRunner, ScyllaSetup } from 'backend-shared';
import config from '../config';
import { RUNNERS } from './job';

const setup = async function() {
  cknex.setDefaultKeyspace('irs_990_api');
  const graphqlFolders = _.filter(fs.readdirSync('./graphql'), file => file.indexOf('.') === -1);
  const scyllaTables = _.flatten(_.map(graphqlFolders, function(folder) {
    const model = require(`../graphql/${folder}/model`);
    return model?.getScyllaTables?.() || [];
}));
  const elasticSearchIndices = _.flatten(_.map(graphqlFolders, function(folder) {
    const model = require(`../graphql/${folder}/model`);
    return model?.getElasticSearchIndices?.() || [];
}));

  const shouldRunSetup = true || (config.get().ENV === config.get().ENVS.PRODUCTION) ||
                    (config.get().SCYLLA.CONTACT_POINTS[0] === 'localhost');

  await Promise.all(_.filter([
    shouldRunSetup ?
      ScyllaSetup.setup(scyllaTables)
      .then(() => console.log('scylla setup')) : undefined,
    shouldRunSetup ?
      ElasticsearchSetup.setup(elasticSearchIndices)
      .then(() => console.log('elasticsearch setup')) : undefined
  ]))
  .catch(err => console.log('setup', err));

  console.log('scylla & elasticsearch setup');
  cknex.enableErrors();
  JobRunner.listen(RUNNERS);
  return null; // don't block
};

const childSetup = function() {
  cknex.setDefaultKeyspace('irs_990_api');
  JobRunner.listen(RUNNERS);
  cknex.enableErrors();
  return Promise.resolve(null); // don't block
};

export { setup, childSetup };
