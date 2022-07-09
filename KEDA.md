# KEDA
- [KEDA](#keda)
  - [Install Operator](#install-operator)
  - [Scale by Application Metrics](#scale-by-application-metrics)
    - [Prepare Application](#prepare-application)
    - [Configure ScaledObject](#configure-scaledobject)
    - [Test](#test)

## Install Operator

- install KEDA Operator
  
  ![](images/keda-operator.png)

- create keda controller in namesapce keda
  
  ```bash
  oc create -f manifests/keda-controller.yaml
  ```
  
  Verify status

  ```bash
  oc -n keda get pods
  ```

  output
  
  ```bash
  NAME                                     READY   STATUS    RESTARTS   AGE
  keda-metrics-apiserver-d9df8cc9c-h9t7m   1/1     Running   0          1m
  keda-olm-operator-785f98bc6d-6lvbw       1/1     Running   0          29s
  keda-operator-75bf78b6fb-kjzzd           1/1     Running   0          1m
  ```

## Scale by Application Metrics

### Prepare Application
- Enable [user workload monitoring](application-metrics.md#prerequisites)
- Deploy frontend-v1 and backend-v1 application to namespace project1
  
  ```bash
  oc apply -f manifests/frontend.yaml -n project1
  oc apply -f manifests/backend.yaml -n project1
  oc set env deployment/frontend-v1 BACKEND_URL=http://backend:8080/ -n project1
  oc set env deployment/frontend-v2 BACKEND_URL=http://backend:8080/ -n project1
  oc delete deployment frontend-v2 -n project1
  oc delete deployment backend-v2 -n project1
  ```
- Create [service monitor](manifests/backend-monitor.yaml) for backend app
  
  ```bash
  oc apply -f manifests/backend-monitor.yaml -n project1
  ```

### Configure ScaledObject

- Create Service Account for KEDA to use for query Thanos
  
  ```bash
  oc create sa app-monitor
  ```

- Add role *cluster-monitoring-view* to service account
  
  ```bash
  oc adm policy add-cluster-role-to-user cluster-monitoring-view \
  -z app-monitor -n project1
  ```

- Let's say we want to scale backend by concurrent request of each pod. Following PromQL will average concurrent request/sec for each pod
  
  ```
  avg(rate(application_com_example_quarkus_BackendResource_countBackend_total[1m]))
  ```

- Create [ScaledObject](manifests/keda-prometheus-scaledout.yaml)

  ```bash
  BEARER_TOKEN=$(oc serviceaccounts get-token  app-monitor -n project1|base64)
  CUSTOM_CA_CERT=$(oc get -n openshift-monitoring secret thanos-querier-tls -o jsonpath="{.data['tls\.crt']}")
  echo $BEARER_TOKEN | cat manifests/keda-prometheus-scaledout.yaml| \
  sed 's/BEARER_TOKEN/'$TOKEN'/'| \
  sed 's/CUSTOM_CA_CERT/'$CUSTOM_CA_CERT'/'| \
  oc create -n project1 -f -
  ```

  Verify status

  ```bash
  oc get -n project1 scaledobject.keda.sh/prometheus-scaledobject
  ```

  Output

  ```bash
  NAME                      SCALETARGETKIND      SCALETARGETNAME   MIN   MAX   TRIGGERS     AUTHENTICATION    READY   ACTIVE   FALLBACK   AGE
  prometheus-scaledobject   apps/v1.Deployment   backend-v1        1     20    prometheus   keda-prom-creds   True    False    False      2m
  ```

### Test

- Create 50 concurrent request to application
  
  ```bash
  siege -c 50 -t 5m https://$(oc get route frontend -n project1 -o yaml -o jsonpath='{.spec.host}')
  ```

  Check on Developer console

  ![](metrics/../images/keda-observe-app-metrics.png)

- Check event from Developer console
  
  ![](images/keda-scale-up.png)

- When workload goes down after 2 minutes
  
  ```yaml
  spec:
    pollingInterval: 10
    cooldownPeriod: 120
    minReplicaCount: 1
    maxReplicaCount: 20  
  ```

  check event from Developer console

  ![](images/keda-scale-down.png)

