# Deployment Strategy with OpenShift Route
<!-- TOC -->

- [Deployment Strategy with OpenShift Route](#deployment-strategy-with-openshift-route)
  - [Application Deployment](#application-deployment)
  - [Blue/Green Deployment](#bluegreen-deployment)
  - [Canary Deployment](#canary-deployment)
  - [Restrict TLS to v1.2](#restrict-tls-to-v12)

<!-- /TOC -->
## Application Deployment
Deploy 2 version of frontend app. Each deployment and service use label **app** and **version** for select each version. 
Initial Route will routing all traffic to v1.

- Deploy frontend v1 and v2 and create route ([frontend.yaml](manifests/frontend.yaml))
  ```bash
  oc apply -f manifests/frontend.yaml -n project1
  ```

## Blue/Green Deployment
- Test Route
  ```bash
  FRONTEND_URL=https://$(oc get route frontend -n project1 -o jsonpath='{.spec.host}')
  while [ 1 ];
  do
     curl $FRONTEND_URL/version
     echo
     sleep 1
  done
  ```
- Use another terminal to patch route to frontend v2
  ```bash
  oc patch route frontend  -p '{"spec":{"to":{"name":"frontend-v2"}}}' -n project1
  ```
- Check output from cURL that response is from frontend-v2
- Set route back to v1
  ```bash
  oc patch route frontend  -p '{"spec":{"to":{"name":"frontend-v1"}}}' -n project1
  ```
- Check output from cURL that response is from frontend-v1
## Canary Deployment
- Apply route for Canary deployment to v1 and v2 with 80% and 20% ratio ([route-with-alternate-backend.yaml](manifests/route-with-alternate-backend.yaml))
  ```bash
  oc apply -f manifests/route-with-alternate-backend.yaml -n project1
  ```
- Call frontend for 10 times. You will get 8 responses from v1 and 2 responses from v2
  ```bash
  FRONTEND_URL=https://$(oc get route frontend -n project1 -o jsonpath='{.spec.host}')
  COUNT=0
  while [ $COUNT -lt 10 ];
  do
    curl $FRONTEND_URL/version
    echo
    sleep .2
    COUNT=$(expr $COUNT + 1)
  done
  ```
- Update weight to 60% and 40%
  ```bash
  oc patch route frontend  -p '{"spec":{"to":{"weight":60}}}' -n project1 
  oc patch route frontend --type='json' -p='[{"op":"replace","path":"/spec/alternateBackends/0/weight","value":40}]' -n project1 
  ```
- Re-run previous bash script to loop frontend. This times you will get 6 responses from v1 and 4 responses from v2
  
## Restrict TLS to v1.2
- Check default ingresscontroller by run command or use OpenShift Web Admin Console

```bash
oc edit ingresscontroller default -n openshift-ingress-operator
```
Use Web Admin Console to search for ingressscontroller and select default

![](images/ingress-controller-01.png)


- Minimum TLS version can be specified by attribute **minTLSVersion**

![](images/ingress-controller-02.png)
  