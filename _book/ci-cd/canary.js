import http from 'k6/http';
import { sleep } from 'k6';
export default function () {
  http.get('http://canary-bot.apps.cluster-852b.852b.example.opentlc.com/api/values/information');
  sleep(1);
}
