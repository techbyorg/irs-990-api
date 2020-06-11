let resolvers, schemaDirectives;
import fs from 'fs';
import _ from 'lodash';
import log from 'loga';
import cors from 'cors';
import express from 'express';
import Promise from 'bluebird';
import bodyParser from 'body-parser';
import cluster from 'cluster';
import http from 'http';

// socketIORedis = require 'socket.io-redis'
import Redis from 'ioredis';

import router from 'exoid-router';
import { ApolloServer } from 'apollo-server-express';
import { buildFederatedSchema } from '@apollo/federation';
import { SchemaDirectiveVisitor } from 'graphql-tools';
import config from './config';
import helperConfig from 'backend-shared/lib/config';
helperConfig.set(_.pick(config, config.SHARED_WITH_PHIL_HELPERS));
const {Schema} = require('backend-shared');
const {setup, childSetup} = require('./services/setup');

const directives = require('./graphql/directives');
let typeDefs = fs.readFileSync('./graphql/type.graphql', 'utf8');

let schema = Schema.getSchema({directives, typeDefs, dirName: __dirname});

Promise.config({warnings: false});

const app = express();
app.set('x-powered-by', false);
app.use(cors());
app.use(bodyParser.json({limit: '1mb'}));
// Avoid CORS preflight
app.use(bodyParser.json({type: 'text/plain', limit: '1mb'}));
app.use(bodyParser.urlencoded({extended: true})); // Kiip uses

app.get('/', (req, res) => res.status(200).send('ok'));

const validTables = [
  'irs_orgs', 'irs_org_990s', 'irs_funds', 'irs_fund_990s',
  'irs_persons', 'irs_contributions'
];
app.get('/tableCount', function(req, res) {
  if (validTables.indexOf(req.query.tableName) === -1) {
    res.send({error: 'invalid table name'});
  }
  const {elasticsearch} = require('backend-shared');
  return elasticsearch.count({
    index: req.query.tableName
  })
  .then(c => res.send(JSON.stringify(c)));
});

app.get('/unprocessedCount', function(req, res) {
  const IrsOrg990 = require('./graphql/irs_org_990/model');
  return IrsOrg990.search({
    trackTotalHits: true,
    limit: 1, // 16 cpus, 16 chunks
    query: {
      bool: {
        must: {
          range: {
            importVersion: {
              lt: config.CURRENT_IMPORT_VERSION
            }
          }
        }
      }
    }
  })
  .then(c => res.send(JSON.stringify(c)));
});

// settings that supposedly make ES bulk insert faster
// (refresh interval -1 and 0 replicas). but it doesn't seem to make it faster
app.get('/setES', async function(req, res) {
  let replicas;
  const {elasticsearch} = require('backend-shared');

  if (req.query.mode === 'bulk') {
    replicas = 0;
    // refreshInterval = -1
  } else { // default / reset
    replicas = 2;
  }
    // refreshInterval = null

  return res.send(await Promise.map(validTables, async function(tableName) {
    const settings = await elasticsearch.indices.getSettings({
      index: tableName
    });
    const previous = settings[tableName].settings.index;
    const diff =
      {number_of_replicas: replicas};
      // refresh_interval: refreshInterval
    await elasticsearch.indices.putSettings({
      index: tableName,
      body: diff
    });
    return JSON.stringify({previous, diff});
  }
  , {concurrency: 1}));
});

app.get('/setMaxWindow', async function(req, res) {
  if (validTables.indexOf(req.query.tableName) === -1) {
    res.send({error: 'invalid table name'});
  }

  const maxResultWindow = parseInt(req.query.maxResultWindow);
  if ((maxResultWindow < 10000) || (maxResultWindow > 100000)) {
    res.send({error: 'must be number between 10,000 and 100,000'});
  }

  const {elasticsearch} = require('backend-shared');

  return res.send(await elasticsearch.indices.putSettings({
    index: req.query.tableName,
    body: {max_result_window: maxResultWindow}
  }));
});

// 2500/s on 4 pods each w/ 4vcpu (1.7mm total) = ~11 min
// bottleneck is queries-in-flight limit for scylla & es
// (throttled by # of cpus / concurrencyPerCpu in jobs settings / queue rate limiter)
// realistically the queue rate limiter is probably the blocker (x per second)
// set to as high as you can without getting scylla complaints.
// 25/s seems to be the sweet spot with current scylla/es setup (1 each)
app.get('/setNtee', function(req, res) {
  const {setNtee} = require('./services/irs_990_importer/set_ntee');
  setNtee();
  return res.send('syncing');
});

// pull in all eins / xml urls that filed for a given year
// run for 2014, 2015, 2016, 2017, 2018, 2019, 2020
// 2015, 2016 done FIXME rm this line
// each takes ~3 min (1 cpu)
// bottleneck is elasticsearch writes (bulk goes through, but some error if server is overwhelmed).
app.get('/loadAllForYear', function(req, res) {
  const {loadAllForYear} = require('./services/irs_990_importer/load_all_for_year');
  loadAllForYear(req.query.year);
  return res.send(`syncing ${req.query.year || 'sample_index'}`);
});

// go through every 990 we haven't processed, and get data for it from xml file/irsx
// ES seems to be main bottleneck. we bulk reqs, but they're still slow.
// 1/2 of time is spent on irsx, 1/2 on es upserts
// if we send too many bulk reqs at once, es will start to send back errors
// i think the issue is bulk upserts in ES are just slow in general.

// faster ES node seems to help a little, but not much...
// cheapest / best combo seems to be 4vcpu/8gb for ES, 8x 2vcpu/2gb for api.
// ^^ w/ 2 job concurrencyPerCpu, that's 32. 32 * 300 (chunk) = 9600 (limit)
//    seems to be sweet spot w/ ~150-250 orgs/s (2-3 hours total)
//    could probably go faster with more cpus (bottleneck at this point is irsx)
// might need to increase thread_pool.write.queue_size to 1000
app.get('/processUnprocessedOrgs', function(req, res) {
  const {processUnprocessedOrgs} = require('./services/irs_990_importer');
  processUnprocessedOrgs(req.query);
  return res.send('processing orgs');
});

app.get('/processEin', function(req, res) {
  const {processEin} = require('./services/irs_990_importer');
  processEin(req.query.ein, {type: req.query.type});
  return res.send('processing org');
});

app.get('/fixBadFundImports', function(req, res) {
  const {fixBadFundImports} = require('./services/irs_990_importer');
  fixBadFundImports({limit: req.query.limit});
  return res.send('fixing bad fund imports');
});

// chunkConcurrency=10
// chunkConcurrency = how many orgs of a chunk to process simultaneously...
// doesn't matter for orgs, but for funds it does (since there's an es fetch)
// sweet spot is 1600&chunkSize=50&chunkConcurrency=3 (slow)
// even with that, scylla might fail upserts for large funds
// so maybe run at chunk 1 concurrency 1 for assets > 100m
app.get('/processUnprocessedFunds', function(req, res) {
  const {processUnprocessedFunds} = require('./services/irs_990_importer');
  processUnprocessedFunds(req.query);
  return res.send('processing funds');
});

app.get('/parseGrantMakingWebsites', function(req, res) {
  const {parseGrantMakingWebsites} = require('./services/irs_990_importer/parse_websites');
  parseGrantMakingWebsites();
  return res.send('syncing');
});

({typeDefs, resolvers, schemaDirectives} = schema);
schema = buildFederatedSchema({typeDefs, resolvers});
// https://github.com/apollographql/apollo-feature-requests/issues/145
SchemaDirectiveVisitor.visitSchemaDirectives(schema, schemaDirectives);

const defaultQuery = `\
query($query: ESQuery!) {
  irsOrgs(query: $query) {
    nodes {
      name
      employeeCount
      volunteerCount
    }
  }
}\
`;

const defaultQueryVariables = `\
{
  "query": {"range": {"volunteerCount": {"gte": 10000}}}
}\
`;

const graphqlServer = new ApolloServer({
  schema,
  introspection: true,
  playground: {
    // settings:
    tabs: [
      {
        endpoint: config.ENV === config.ENVS.DEV ?
          `http://localhost:${config.PORT}/graphql`
        :
          'https://api.techby.org/990/v1/graphql',
        query: defaultQuery,
        variables: defaultQueryVariables
      }
    ]
  }


});
graphqlServer.applyMiddleware({app, path: '/graphql'});

const server = http.createServer(app);

export { server, setup, childSetup };
