import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: `${__ENV.RAMPUP}`, target:`${__ENV.THREADS}`},
    { duration: `${__ENV.DURATION}`, target: `${__ENV.THREADS}`},
    { duration: `${__ENV.RAMPDOWN}`, target: 0 },
  ],
};

export default function() {
  let res = http.get(`${__ENV.URL}`);
  console.log(res.body);
};
