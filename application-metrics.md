# User Workload Metrics
<!-- TOC -->

- [User Workload Metrics](#user-workload-metrics)
    - [Prerequisites](#prerequisites)
    - [Service Monitoring](#service-monitoring)

<!-- /TOC -->
## Prerequisites
- Setup [User Workload Monitoring](manifests/user-workload-monitoring.yaml)
```bash
oc apply -f  manifests/user-workload-monitoring.yaml
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
## Service Monitoring
- Deploy application with custom metrics
  - Backend application provides metrics by /metrics and /metrics/applications
    ```bash
    oc apply -f manifests/frontend.yaml -n project1
    oc apply -f manifests/backend.yaml -n project1
    oc set env deployment/frontend-v1 BACKEND_URL=http://backend:8080/ -n project1
    oc set env deployment/frontend-v2 BACKEND_URL=http://backend:8080/ -n project1
    ```
  - Test backend application metrics
    ```bash
    oc exec -n project1 $(oc get pods -n project1 | grep backend | head -n 1 | awk '{print $1}') -- curl http://localhost:8080/metrics
    oc exec -n project1 $(oc get pods -n project1 | grep backend | head -n 1 | awk '{print $1}') -- curl http://localhost:8080/metrics/application
    ```
  - Sample output
    ```bash
    # TYPE vendor_memory_committedNonHeap_bytes gauge
    vendor_memory_committedNonHeap_bytes 3.1780976E7
    # HELP vendor_memory_maxNonHeap_bytes Displays the maximum amount of used non-heap memory in bytes.
    # TYPE vendor_memory_maxNonHeap_bytes gauge
    vendor_memory_maxNonHeap_bytes -1.0
    # HELP vendor_memory_usedNonHeap_bytes Displays the amount of used non-heap memory in bytes.
    # TYPE vendor_memory_usedNonHeap_bytes gauge
    vendor_memory_usedNonHeap_bytes 3.1780976E7
    ```
- Create [Service Monitoring](manifests/backend-service-monitor.yaml) for backend service
```
oc apply -f manifests/backend-service-monitor.yaml -n project1
```
- Developer Console monitoring metrics  
  - Select application metrics

    ![](images/dev-console-custom-metrics.png)

  - Application metrics 
    
    Request counted
    ![](images/dev-console-app-metrics-01.png)

    Concurrent requests
    ![](images/dev-console-app-metrics-02.png)
