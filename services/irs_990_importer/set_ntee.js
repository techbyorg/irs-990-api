import _ from 'lodash';
import requestNonPromise from 'request';
import csv from 'csvtojson';
import fs from 'fs';
import { JobCreate } from 'backend-shared';
import IrsOrg from '../../graphql/irs_org/model';
import JobService from '../../services/job';
import config from '../../config';

export default {
  setNtee() {
    console.log('sync');
    let cache = null;
    return requestNonPromise(config.NTEE_CSV)
    .pipe(fs.createWriteStream('data.csv'))
    .on('finish', function() {
      console.log('file downloaded');
      let chunk = [];
      let i = 0;
      return csv().fromFile('data.csv')
      .subscribe((function(json) {
        i += 1;
        // batch every 100 for upsert
        if (i && !(i % 100)) {
          console.log(i);
          cache = chunk;
          chunk = [];
          JobCreate.createJob({
            queue: JobService.QUEUES.DEFAULT,
            waitForCompletion: true,
            job: {orgs: cache, i},
            type: JobService.TYPES.DEFAULT.IRS_990_UPSERT_ORGS,
            ttlMs: 60000,
            priority: JobService.PRIORITIES.NORMAL
          })
          .catch(err => console.log('err', err));
        }

        return chunk.push({
          ein: json.EIN,
          name: json.NAME,
          city: json.CITY,
          state: json.STATE,
          nteecc: json.NTEECC
        });
      }), (() => console.log('error')), function() {
        console.log('done');
        return IrsOrg.batchUpsert(cache);
      });
    });
  }
};
