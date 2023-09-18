import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  // scenarios: {
  //   constant_request_rate: {
  //     executor: 'constant-arrival-rate',
  //     rate: 1,
  //     timeUnit: '1s',
  //     duration: '1m',
  //     preAllocatedVUs: 20,
  //     maxVUs: 100,
  //   },
  // },
  stages: [
    { duration: `${__ENV.RAMPUP}`, target:`${__ENV.THREADS}`},
    { duration: `${__ENV.DURATION}`, target: `${__ENV.THREADS}`},
    { duration: `${__ENV.RAMPDOWN}`, target: 0 },
  ],
  // insecureSkipTLSVerify: true
};

export default function() {
  let res = http.get(`${__ENV.URL}`);
  console.log(res.body);
};
