# User Workload Metrics
<!-- TOC -->

- [User Workload Metrics](#user-workload-metrics)
  - [Prerequisites](#prerequisites)
  - [Custom Grafana Dashboard](#custom-grafana-dashboard)
  - [Custom Alert](#custom-alert)

<!-- /TOC -->
## Prerequisites
- Setup [User Workload Monitoring](manifests/cluster-monitoring-config.yaml)
  
  <!-- ```bash
  oc apply -f  manifests/user-workload-monitoring.yaml
  ``` -->

  <!-- Remark: You also need to setup and configure [cluster monitoring](infrastructure-monitoring-alerts.md) or use following [simple configuration](manifests/cluster-monitoring-config.yaml). You may need to change *storageClassName* based on your cluster configuration -->

  Remark: You may need to change *storageClassName* based on your cluster configuration
  
  ```bash
  oc apply -f  manifests/cluster-monitoring-config.yaml
  sleep 10
  oc -n openshift-user-workload-monitoring wait --for condition=ready \
   --timeout=180s pod -l app.kubernetes.io/name=prometheus
  oc -n openshift-user-workload-monitoring wait --for condition=ready \
   --timeout=180s pod -l app.kubernetes.io/name=thanos-ruler
  ```

  Output

  ```bash
  configmap/cluster-monitoring-config created
  pod/prometheus-user-workload-0 condition met
  pod/prometheus-user-workload-1 condition met
  pod/thanos-ruler-user-workload-0 condition met
  pod/thanos-ruler-user-workload-1 condition met
  ```

- Verify monitoring stack
  
  ```bash
  oc  get pod -n openshift-user-workload-monitoring
  ```

  Sample output
  
  ```bash
  NAME                                   READY   STATUS    RESTARTS   AGE
  prometheus-operator-5fc7d894dc-9nlhc   2/2     Running   0          9m3s
  prometheus-user-workload-0             4/4     Running   1          5m45s
  prometheus-user-workload-1             4/4     Running   1          6m1s
  thanos-ruler-user-workload-0           3/3     Running   5          8m55s
  thanos-ruler-user-workload-1           3/3     Running   0          11s
  ```
- CPU and Memory used by User Workload Monitoring
  
  Overall resouces consumed by user workload monitoring

  ![](images/user-workload-monitoring-overall-resources.png)

  CPU Usage
  
  ![](images/user-workload-monitoring-cpu-usage.png)

  Memory Usage

  ![](images/user-workload-minitoring-memory-usage.png)

  CPU Quota
  
  ![](images/user-workload-monitoring-cpu-quota.png)

  Memory Quota

  ![](images/user-workload-monitoring-memory-quota.png)
  
## Service Monitoring

- Deploy application with custom metrics

  ```bash
  oc create -f manifests/frontend-v1-and-backend-v1-JVM.yaml -n project1
  ```
    
  - Check for backend's metrics
  
    ```bash
    oc exec -n project1 $(oc get pods -l app=backend \
    --no-headers  -o custom-columns='Name:.metadata.name' \
    -n project1 | head -n 1 ) \
    -- curl -s  http://localhost:8080/q/metrics | grep http_
    ```
    Sample output
  
    ```bash
    # TYPE jvm_gc_memory_allocated_bytes_total counter
    jvm_gc_memory_allocated_bytes_total 1.9580992E7
    # HELP jvm_gc_overhead_percent An approximation of the percent of CPU time used by GC activities over the last lookback period or since monitoring began, whichever is shorter, in the range [0..1]
    # TYPE jvm_gc_overhead_percent gauge
    jvm_gc_overhead_percent 0.003830234812943298
    ```

  - Check for backend application related metrics
  
    ```bash
    curl https://$(oc get route frontend -n project1 -o jsonpath='{.spec.host}')
    oc exec -n project1 $(oc get pods -l app=backend \
    --no-headers  -o custom-columns='Name:.metadata.name' \
    -n project1 | head -n 1 ) \
    -- curl -s  http://localhost:8080/q/metrics | grep http_server_requests_seconds
    ```
    
    Check that http_server_requests_seconds_count with method GET and root URI value is 1 with return status 200
  
    ```bash
    # HELP http_server_requests_seconds
    # TYPE http_server_requests_seconds summary
    http_server_requests_seconds_count{method="GET",outcome="SUCCESS",status="200",uri="root",} 1.0
    http_server_requests_seconds_sum{method="GET",outcome="SUCCESS",status="200",uri="root",} 2.64251063
    # HELP http_server_requests_seconds_max
    # TYPE http_server_requests_seconds_max gauge
    http_server_requests_seconds_max{method="GET",outcome="SUCCESS",status="200",uri="root",} 2.64251063
    ```

    
- Create [Service Monitoring](manifests/backend-monitor.yaml) to monitor backend service
    
    ```yaml
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: backend-monitor
    spec:
      endpoints:
      - interval: 30s
        port: http
        path: /q/metrics # Get metrics from URI /q/metrics
        scheme: http
      selector:
        matchLabels:
          app: backend # select only label app = backend
    ```

    Create service monitor

    ```bash
    oc apply -f manifests/backend-service-monitor.yaml -n project1
    ```
    
    Remark: Role **monitor-edit** is required for create **ServiceMonitor** and **PodMonitor** resources. Following example is granting role montior-edit to user1 for project1

    ```bash
    oc adm policy add-role-to-user  monitoring-edit user1 -n project1
    ```
    
- Developer Console monitoring metrics  
  - Select application metrics

    ![](images/dev-console-custom-metrics.png)

  - Application metrics 
  
    - Scale backend-v1 and frontend-v1 to 5 pod and run load test tool

      ```bash
      oc scale deployment backend-v1 --replicas=5 -n project1
      oc scale deployment frontend-v1 --replicas=5 -n project1
      ```

      - Use K6
  
      ```bash
       oc run load-test-frontend -n project1 \
      -i --image=loadimpact/k6  \
      --rm=true --restart=Never --  run -< manifests/load-test-k6.js \
      -e URL=http://frontend:8080 \
      -e THREADS=10 \
      -e RAMPUP=30s \
      -e DURATION=3m \
      -e RAMPDOWN=30s \
      -e K6_NO_CONNECTION_REUSE=true
      ```
    
      - Use Siege 

      ```bash
      oc create -f manifests/tools.yaml -n project1
      TOOL=$(oc get po -n project1 -l app=network-tools --no-headers  -o custom-columns='Name:.metadata.name')
      ```

      Run siege command

      ```bash
      oc exec -n project1 $TOOL -- siege -c 20 -t 4m http://frontend:8080
      ```
    
    - PromQL for query request/sec for GET method to root URI of backend service
    
      ```
      rate(http_server_requests_seconds_count{method="GET",uri="root"}[1m])
      ```

      Sample stacked graph

      ![](images/dev-console-app-metrics-01.png)

    <!-- - PromQL for query concurrent requests
      
      ```
      application_com_example_quarkus_BackendResource_concurrentBackend_current
      ``` -->
      
      <!-- Sample stacked graph

      ![](images/dev-console-app-metrics-02.png) -->

## Custom Grafana Dashboard
<!-- https://access.redhat.com/solutions/5335491 -->
Use **Grafana Operator by Red Hat** to deploy Grafana and configure datasource to Thanos Querier

Remark: **Grafana Operator is Community Edition - not supported by Red Hat**

- Create project
  
  ```bash
  oc new-project application-monitor --display-name="App Dashboard" --description="Grafana Dashboard for Application Monitoring"
  ```
  
- Install Grafana Operator to project application-monitor
  - Install Grafana Operator from OperatorHub

  ![](images/grafana-operator-01.png)

  - Install to application-monitor project
  
  ![](images/grafana-operator-02.png)
  
- Create [Grafana instance](manifests/grafana.yaml)
  
  ```bash
  oc create -f manifests/grafana.yaml -n application-monitor
  watch -d oc get pods -n application-monitor
  ```
  
  Sample Output
  
  ```bash
  NAME                                 READY   STATUS    RESTARTS   AGE
  grafana-deployment-cd4764497-jcwtx   1/1     Running   0          52s
  grafana-operator-7d585d8fb4-nks8s    1/1     Running   0          4m55s
  ```
  
- Add cluster role `cluster-monitoring-view` to Grafana ServiceAccount

  ```bash
  oc adm policy add-cluster-role-to-user cluster-monitoring-view \
  -z grafana-serviceaccount -n application-monitor
  ```

- Create [Grafana DataSource](manifests/grafana-datasource.yaml) with serviceaccount grafana-serviceaccount's token and connect to thanos-querier

  ```bash
  TOKEN=$(oc serviceaccounts get-token grafana-serviceaccount -n application-monitor)
  cat manifests/grafana-datasource.yaml|sed 's/Bearer .*/Bearer '"$TOKEN""'"'/'|oc apply -n application-monitor -f -
  ```  

- Create [Grafana Dashboard](manifests/grafana-dashboard.yaml)

  ```bash
  oc apply -f manifests/grafana-dashboard.yaml -n application-monitor 
  ```

- Login to Grafana Dashboard with following URL
  
  ```bash
  echo "Grafana URL => https://$(oc get route grafana-route -o jsonpath='{.spec.host}' -n application-monitor)"
  ```
  
  or use link provided by Developer Console

  ![](images/custom-grafana-route.png)

  Login with user `admin` and password `openshift`
  
- Generate workload
  - bash script to loop request to frontend application.
  
    ```bash
    FRONTEND_URL=https://$(oc get route frontend -n project1 -o jsonpath='{.spec.host}')
    while [ 1 ];
    do
      curl $FRONTEND_URL
      printf "\n"
      sleep .2
    done
    ```

  - k6 load test tool with 10 threads for 5 minutes

    ```bash
    oc run load-test-frontend -n project1 \
    -i --image=loadimpact/k6  \
    --rm=true --restart=Never --  run -< manifests/load-test-k6.js \
    -e URL=http://frontend:8080 \
    -e THREADS=15 \
    -e RAMPUP=30s \
    -e DURATION=5m \
    -e RAMPDOWN=30s
    ```    
  
- Grafana Dashboard
  
  ![](images/grafana-dashboard.png)

## Custom Alert

- Check `PrometheusRule` [backend-app-alert](manifests/backend-custom-alert.yaml)

```yaml

```

  [backend-app-alert](manifests/backend-custom-alert.yaml) is consists with 2 following alerts:
  
  - ConcurrentBackend
    severity warning when total concurrent reqeusts is greater than 40 requests/sec
  
  - HighLatency
    servierity critical when percentile 90th of response time is greater than 5 sec  


- Create [backend-app-alert](manifests/backend-custom-alert.yaml) 

  ```bash
  oc apply -f manifests/backend-custom-alert.yaml
  ```

  Remark: Role `monitoring-rules-view` is required for view `PrometheusRule` resource and role `monitoring-rules-edit` is required to  create, modify, and deleting `PrometheusRule` 
  
  Following example is granting role monitoring-rules-view and monitoring-rules-edit to user1 for project1

  ```bash
  oc adm policy add-role-to-user  monitoring-rules-view user1 -n project1
  oc adm policy add-role-to-user  monitoring-rules-edit user1 -n project1

  ``` 
  
<!-- - For simplified our test, set backend app to 2 pod
  
  ```bash
  oc delete deployment backend-v2 -n project1
  oc scale deployment backend-v1 --replicas=2 -n project1
  ``` -->
  
- Test `ConcurrentBackend` alert with 25 concurrent requests

  ```bash
     oc run load-test-frontend -n project1 \
    -i --image=loadimpact/k6  \
    --rm=true --restart=Never --  run -< manifests/load-test-k6.js \
    -e URL=http://frontend:8080 \
    -e THREADS=15 \
    -e RAMPUP=30s \
    -e DURATION=5m \
    -e RAMPDOWN=30s 
  ```

  Check for alert in Developer Console by select Menu `Monitoring` then select `Alerts`

  ![](images/alert-concurrent-backend.png)

<!-- - Test `HighLatency` alert
  - Set backend with 6 sec response time
    - By CLI
      ```bash
      oc set env deployment/backend-v1 APP_BACKEND=https://httpbin.org/delay/6 -n project1
      ```
    - By Developer Console
      - Select `Topology` then select backend-v1 and select dropdown menu `Edit Deployment`
        
        ![](images/dev-console-edit-deployment.png)
        
      - Select `Environment` and set APP_BACKEND to https://httpbin.org/delay/6

        ![](images/dev-console-edit-environment.png) -->
  <!-- - Request to frontend app
    
    ```bash
    curl $FRONTEND_URL
    ``` -->
  - Check for alert in Developer Console 
    
    ![](images/alert-high-latency.png)

  - Console overview status

    ![](images/console-overview-status.png)