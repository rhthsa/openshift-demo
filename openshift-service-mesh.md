# OpenShift Service Mesh
<!-- TOC -->

- [OpenShift Service Mesh](#openshift-service-mesh)
  - [Setup Control Plane and sidecar](#setup-control-plane-and-sidecar)
  - [Create Istio Gateway](#create-istio-gateway)
  - [Weight-Routing with Istio Virtual Service](#weight-routing-with-istio-virtual-service)
  - [Routing by condition based on URI](#routing-by-condition-based-on-uri)
  - [A/B with Istio Virtual Service](#ab-with-istio-virtual-service)
  - [Traffic Analysis](#traffic-analysis)
  - [Distributed Tracing](#distributed-tracing)
  - [Traffic Mirroring (Dark Launch)](#traffic-mirroring-dark-launch)
  - [Envoy Access Log](#envoy-access-log)

<!-- /TOC -->
## Setup Control Plane and sidecar
- Install following Operators from OperatorHub
  - ElasticSearch
  - Jaeger
  - Kiali
  - OpenShift Service Mesh
- Create control plane by create ServiceMeshControlPlane CRD
  ```bash
  oc new-project istio-system
  oc create -f manifests/smcp.yaml -n istio-system
  ```
- Check for control plane([get-smcp-status.sh](bin/get-smcp-status.sh))
  ```bash
  bin/get-smcp-status.sh istio-system
  ```
- Join project1 into control plane
  - Review [ServiceMeshMemberRoll CRD](manifests/smcp.yaml)
    ```yaml
    apiVersion: maistra.io/v1
    kind: ServiceMeshMemberRoll
    metadata:
      name: default
    spec:
      members:
      - project1
    ```
  - Apply ServiceMeshMemberRoll
    ```bash
    oc create -f manifests/smmr.yaml -n istio-system
    ```
  - Check for ServiceMeshMemberRoll status
    ```bash
    oc describe smmr/default -n istio-system | grep -A2 Spec:
    ```
- Deploy sidecar to frontend app in project1
  ```bash
  oc patch deployment/frontend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n project1
  oc patch deployment/frontend-v2 -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n project1
  ```
- Check for sidecar in frontend-v1 and frontend-v2 pods
  ```bash
  oc get pods -n project1
  ```
- Create [frontend service](mainfests/../manifests/frontend-service.yaml)
    ```
    oc create -f manifests/frontend-service.yaml -n project1
    ```

## Create Istio Gateway
- Create Gateway for frontend app
  - Check for cluster's sub-domain
    ```bash
    SUBDOMAIN=$(oc whoami --show-console|awk -F'apps.' '{print $2}')
    echo $SUBDOMAIN
    ```
  - Review [Gateway CRD](manifests/frontend-gateway.yaml), Replaced SUBDOMAIN with cluster's sub-domain
    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: Gateway
    metadata:
    name: frontend-gateway
    spec:
    selector:
        istio: ingressgateway # use istio default controller
    servers:
    - port:
        number: 80
        name: http2
        protocol: HTTP
        hosts:
        - '*.apps.SUBDOMAIN'
        
    ```
  - Create gateway
    ```bash
    oc apply -f manifests/frontend-gateway.yaml -n istio-system
    ```
- Create Destination Rule for frontend v1 and frontend v2
  - Review [Destination Rule CRD](manifests/frontend-destination-rule.yaml)
    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: DestinationRule
    metadata:
        name: frontend
    spec:
        host: frontend
        subsets:
        - name: v1
        labels:
            app: frontend
            version: v1
        trafficPolicy:
            loadBalancer:
            simple: ROUND_ROBIN
        - name: v2
        labels:
            app: frontend
            version: v2
        trafficPolicy:
            loadBalancer:
            simple: ROUND_ROBIN
    ```
  - Create destination rule
    ```bash
    oc apply -f manifests/frontend-destination-rule.yaml -n project1
    ```
- Create Virtual Service for frontend app
  - Review [Virtual Service CRD](manifests/frontend-virtual-service.yaml), Replace SUBDOMAIN with cluster's sub-domain.
    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
        name: frontend
    spec:
        hosts:
        - frontend.apps.SUBDOMAIN
        gateways:
        - istio-system/frontend-gateway
        http:
        - route:
        - destination:
            port:
                number: 8080
            host: frontend.project1.svc.cluster.local
    ```
  - Create virtual service
    ```bash
    oc apply -f manifests/frontend-virtual-service.yaml -n project1
    ```
- Create Route (configured with Istio Gateway) for frontend app
  - Review [Route](manifests/frontend-route-istio.yaml), Replace SUBDOMAIN with cluster's subdomain
    ```yaml
    apiVersion: v1
    kind: Route
    metadata:
        name: frontend
    spec:
        host: frontend.apps.SUBDOMAIN
        port:
        targetPort: http2
        to:
        kind: Service
        name: istio-ingressgateway
        weight: 100
        wildcardPolicy: None

    ```
  - Create Route
    ```
    oc apply -f manifests/frontend-route-istio.yaml -n istio-system
    ```
- Test with cURL
```bash
FRONTEND_ISTIO_ROUTE=$(oc get route frontend -n istio-system -o jsonpath='{.spec.host}')
curl $FRONTEND_ISTIO_ROUTE
```
## Weight-Routing with Istio Virtual Service
- Set weight routing between 2 services with virtual service
  - Check for [virtual service with weight routing](manifests/frontend-virtual-service-with-weight-routing.yaml), Replace SUBDOMAIN with cluster's subdomain.
  ```yaml
  apiVersion: networking.istio.io/v1alpha3
  kind: VirtualService
  metadata:
    name: frontend
  spec:
    hosts:
    - frontend.apps.SUBDOMAIN
    gateways:
    - istio-system/frontend-gateway
    http:
    - route:
      - destination:
          port:
            number: 8080
          host: frontend.project1.svc.cluster.local
          subset: v1
        weight: 100
      - destination:
          port:
            number: 8080
          host: frontend.project1.svc.cluster.local
          subset: v2
        weight: 0
  ```
    - Apply [virtual service](manifests/frontend-virtual-service-with-weight-routing.yaml) for Blue/Green deployment with route all traffic to v1
    ```bash
    oc apply -f manifests/frontend-virtual-service-with-weight-routing.yaml -n project1
    ```
  - Test with cURL to verify that all requests are routed to v1
  - Blue/Green deployment by route all requests to v2
    ```bash
    oc patch virtualservice frontend --type='json' -p='[{"op":"replace","path":"/spec/http/0","value":{"route":[{"destination":{"host":"frontend.project1.svc.cluster.local","port":{"number":8080},"subset":"v1"},"weight":0},{"destination":{"host":"frontend.project1.svc.cluster.local","port":{"number":8080},"subset":"v2"},"weight":100}]}}]' -n project1
    ```
  - Test with cURL to verify that all requests are routed to v2
  - Canary deployment by weight requests between v1 and v2 with 70% and 30%
    ```bash
    oc patch virtualservice frontend --type='json' -p='[{"op":"replace","path":"/spec/http/0","value":{"route":[{"destination":{"host":"frontend.project1.svc.cluster.local","port":{"number":8080},"subset":"v1"},"weight":70},{"destination":{"host":"frontend.project1.svc.cluster.local","port":{"number":8080},"subset":"v2"},"weight":30}]}}]' -n project1
    ```
- Test canary deployment
  - Run 100 requests
    ```bash
    FRONTEND_ISTIO_ROUTE=http://$(oc get route frontend -n istio-system -o jsonpath='{.spec.host}')
    COUNT=0
    rm -f result.txt
    while [ $COUNT -lt 100 ];
    do
        OUTPUT=$(curl -s $FRONTEND_ISTIO_ROUTE/version)
        printf "%s\n" $OUTPUT >> result.txt
        printf "%s\n" $OUTPUT
        sleep .2
        COUNT=$(expr $COUNT + 1)
    done
    ```
  - Check result
    ```bash
    printf "Version 1: %s\n" $(cat result.txt | grep "1.0.0" | wc -l)
    printf "Version 2: %s\n" $(cat result.txt | grep "2.0.0" | wc -l)
    rm -f result.txt
    ```
## Routing by condition based on URI
- Set conditional routing between 2 services with virtual service
  - Check for [virtual service by URI](manifests/frontend-virtual-service-with-uri.yaml), Replace SUBDOMAIN with cluster's subdomain. Condition with regular expression
      - Route to v1 if request URI start with "/ver" and end with "1"
    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
    name: frontend
    spec:
    hosts:
    - frontend.apps.SUBDOMAIN
    gateways:
    - istio-system/frontend-gateway
    http:
    - match:
        - uri:
            regex: /ver(.*)1
        rewrite:
        # Rewrite URI back to / because frontend app not have /ver(*)1
        uri: "/"
        route:
        - destination:
            host: frontend
            port:
            number: 8080
            subset: v1
    - route:
        - destination:
            host: frontend
            port:
            number: 8080
            subset: v2
    ```
- Apply virtual service
  ```bash
  oc apply -f manifests/frontend-virtual-service-with-uri.yaml -n project1
  ```
- Test with URI /version1 and /ver1
  ```bash
  FRONTEND_ISTIO_ROUTE=http://$(oc get route frontend -n istio-system -o jsonpath='{.spec.host}')
  curl $FRONTEND_ISTIO_ROUTE/version1
  curl $FRONTEND_ISTIO_ROUTE/vers1
  curl $FRONTEND_ISTIO_ROUTE/ver1
  ```
- Test with URI /
  ```bash
  FRONTEND_ISTIO_ROUTE=http://$(oc get route frontend -n istio-system -o jsonpath='{.spec.host}')
  curl $FRONTEND_ISTIO_ROUTE/
  ```
## A/B with Istio Virtual Service
- A/B testing by investigating User-Agent header with [Virtual Service](manifests/frontend-virtual-service-with-header.yaml), Replace SUBDOMAIN with cluster's sub-domain.
  - If HTTP header User-Agent contains text Firewall, request will be routed to frontend v2 
  ```yaml
  apiVersion: networking.istio.io/v1alpha3
  kind: VirtualService
  metadata:
    name: frontend
  spec:
    hosts:
    - frontend.apps.SUBDOMAIN
    gateways:
    - istio-gateway/frontend-gateway
    http:
    - match:
      - headers:
          user-agent:
            regex: (.*)Firefox(.*)
      route:
      - destination:
          host: frontend
          port:
            number: 8080
          subset: v2
    - route:
      - destination:
          host: frontend
          port:
            number: 8080
          subset: v1
  ```
- Apply [Virtual Service](manifests/frontend-virtual-service-with-header.yaml)
  ```bash
  oc apply -f manifests/frontend-virtual-service-with-header.yaml -n project1
  ```
- Test with cURL with HTTP header User-Agent contains Firefox
```bash
FRONTEND_ISTIO_ROUTE=http://$(oc get route frontend -n istio-system -o jsonpath='{.spec.host}')
  curl -H "User-Agent:Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:78.0) Gecko/20100101 Firefox/78.0" $FRONTEND_ISTIO_ROUTE
```
## Traffic Analysis
- Deploy backend application
```bash
oc apply -f manifests/backend.yaml -n project1
oc apply -f manifests/backend-destination-rule.yaml -n project1
oc apply -f manifests/backend-virtual-service.yaml -n project1
oc get pods -n project1
```
- Configure frontend to request to backend
```bash
oc set env deployment/frontend-v1 BACKEND_URL=http://backend:8080/ -n project1
oc set env deployment/frontend-v2 BACKEND_URL=http://backend:8080/ -n project1
```
- Check Kiali Console
- login to OpenShift Developer Console, select project istio-system and open Kiali console 

  ![](images/istio-system-project.png)
- Login to Kiali Console and select Graph
  -  Namespace: select checkbox "project1"
  -  Display: select checkbox "Requests percentage" and "Traffic animation"
- Run following command
  ```bash
  oc patch virtualservice frontend --type='json' -p='[{"op":"replace","path":"/spec/http/0","value":{"route":[{"destination":{"host":"frontend.project1.svc.cluster.local","port":{"number":8080},"subset":"v1"},"weight":70},{"destination":{"host":"frontend.project1.svc.cluster.local","port":{"number":8080},"subset":"v2"},"weight":30}]}}]' -n project1
  FRONTEND_ISTIO_ROUTE=http://$(oc get route frontend -n istio-system -o jsonpath='{.spec.host}')
  while [ 1 ];
  do
          OUTPUT=$(curl -s $FRONTEND_ISTIO_ROUTE)
          printf "%s\n" $OUTPUT
          sleep .2
  done
  ```
- Check Kiali Console

  ![](images/istio-system-project.png)

- Traffic analysis for frontend app. Select Application->frontend->inbound traffic and outbound traffic
  
  ![](images/kiali-frontend-inboud-traffic.png)

## Distributed Tracing
- Distributed tracing with Jaeger. Select tab Tracing
  - Overall tracing for frontend app

    ![](images/frontend-app-tracing.png)
    
  - Login to Jaeger by select "View in Tracing"
  
    ![](images/jaeger-main.png)
    
  - Drill down to tracing information

    ![](images/jaeger-transaction.png) 
    
## Traffic Mirroring (Dark Launch)
- Deploy audit app and mirror every requests that frontend call backend to audit app
  ```bash
  oc apply -f manifests/audit-app.yaml -n project1
  oc get pods -n project1
  ```
- Update [backend virtual service](manifests/backend-virtual-service-mirror.yaml) to mirror requests to audit app.
  ```bash
  oc apply -f manifests/backend-virtual-service-mirror.yaml -n project1
  ```
- Use cURL to call frontend and check audit's pod log by CLI (with another terminal) or Web Console
  - cURL frontend
  ```bash
  FRONTEND_ISTIO_ROUTE=http://$(oc get route frontend -n istio-system -o jsonpath='{.spec.host}')
  curl $FRONTEND_ISTIO_ROUTE
  ```

  - View audit log 
  ```bash
  oc logs -f $(oc get pods --no-headers | grep audit|head -n 1|awk '{print $1}') -c backend -n project1
  ```
  
  ![](images/mirror-log.png)
  


  
  
## Envoy Access Log
- Envoy access log already enabled with [ServiceMeshControlPlane CRD](manifests/smcp.yaml)
  ```yaml
    proxy:
    accessLogging:
      envoyService:
        enabled: false
      file:
        encoding: TEXT
        name: /dev/stdout
  ```
- Check access log
  ```bash
  oc logs -f $(oc get pods -n project1 --no-headers|grep frontend|head -n 1|awk '{print $1}') -c istio-proxy -n project1
  ```
- Sample output
  ```log
  [2020-12-25T10:33:04.848Z] "GET / HTTP/1.1" 200 - "-" "-" 0 103 5750 5749 "-" "-" "0c3ce34a-f5a0-9340-b84f-3631cd8eb444" "backend:8080" "10.128.2.133:8080" outbound|8080|v2|backend.project1.svc.cluster.local 10.128.2.131:48300 172.30.116.252:8080 10.128.2.131:36992 - -
  [2020-12-25T10:33:04.846Z] "GET / HTTP/1.1" 200 - "-" "-" 0 184 5756 5755 "184.22.250.124,10.131.0.4" "curl/7.64.1" "0c3ce34a-f5a0-9340-b84f-3631cd8eb444" "frontend.apps.cluster-1138.1138.example.opentlc.com" "127.0.0.1:8080" inbound|8080|http|frontend-v1.project1.svc.cluster.local 127.0.0.1:56540 10.128.2.131:8080 10.131.0.4:0 outbound_.8080_.v1_.frontend.project1.svc.cluster.local default
  ```