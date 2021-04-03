import { check } from 'k6';
import http from 'k6/http';

export default function () {
  var url = 'http://bot-demo-application-front-test1.apps.cluster-b3e9.b3e9.example.opentlc.com/api/values/scaling';
  var payload = JSON.stringify({
  	input: '11'
  });

  var params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  let res = http.post(url, payload, params);
  check(res, {
    'is status 200': (r) => r.status === 200,
  });
}

