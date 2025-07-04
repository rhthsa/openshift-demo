# Logging with Loki
- [Logging with Loki](#logging-with-loki)
  - [Install and Config](#install-and-config)
  - [Test with Sample Applications](#test-with-sample-applications)
  - [Support for multi-lines error log](#support-for-multi-lines-error-log)
  - [LogQL](#logql)
  - [Alert](#alert)

## Install and Config
- Install [Logging Operator](manifests/logging-operator.yaml) and [Loki Operator](manifests/loki-operator.yaml)
  
  ```bash
  oc create -f manifests/openshift-logging-ns.yaml
  oc create -f manifests/logging-operator.yaml
  oc create -f manifests/loki-operator.yaml
  sleep 60
  oc wait --for condition=established --timeout=180s \
  crd/clusterlogforwarders.observability.openshift.io \
  crd/lokistacks.loki.grafana.com
  oc get csv -n openshift-logging
  ```

  Output

  ```bash
  namespace/openshift-logging created
  operatorgroup.operators.coreos.com/cluster-logging created
  subscription.operators.coreos.com/cluster-logging created
  namespace/openshift-operators-redhat created
  operatorgroup.operators.coreos.com/openshift-operators-redhat created
  subscription.operators.coreos.com/loki-operator created
  customresourcedefinition.apiextensions.k8s.io/clusterlogforwarders.observability.openshift.io condition met
  customresourcedefinition.apiextensions.k8s.io/lokistacks.loki.grafana.com condition met
  NAME                     DISPLAY                     VERSION   REPLACES                 PHASE
  cluster-logging.v6.2.3   Red Hat OpenShift Logging   6.2.3     cluster-logging.v6.2.2   Succeeded
  loki-operator.v6.2.3     Loki Operator               6.2.3     loki-operator.v6.2.2     Succeeded
  ```


<!-- oc create sa collector -n openshift-logging
oc adm policy add-cluster-role-to-user logging-collector-logs-writer -z collector -n openshift-logging
oc adm policy add-cluster-role-to-user collect-application-logs -z collector -n openshift-logging
oc adm policy add-cluster-role-to-user collect-audit-logs -z collector -n openshift-logging
oc adm policy add-cluster-role-to-user collect-infrastructure-logs -z collector -n openshift-logging -->
- Create Logging Instance
  - Create Service Account and assign cluster roles to service account.
    
    Use CLI
    
    ```bash
    oc create sa collector -n openshift-logging
    oc adm policy add-cluster-role-to-user logging-collector-logs-writer -z collector -n openshift-logging
    oc adm policy add-cluster-role-to-user collect-application-logs -z collector -n openshift-logging
    oc adm policy add-cluster-role-to-user collect-audit-logs -z collector -n openshift-logging
    oc adm policy add-cluster-role-to-user collect-infrastructure-logs -z collector -n openshift-logging
    ```  

    Use [YAML files](anifests/cluster-logging-operator-role-binding.yaml)

    ```bash
    oc create -f manifests/cluster-logging-operator-role-binding.yaml
    ```        

  - Create [ClusterLogForwarder](manifests/cluster-log-forwarder.yaml) instance
    
    ```bash
    oc create -f manifests/cluster-log-forwarder.yaml
    ```

  - Prepare Object Storage configuration including S3 access Key ID, access Key Secret, Bucket Name, endpoint and Region
    - In case of using ODF
        - Create Bucket
          
          - Admin Console
            - Navigate to Storage -> Object Storage -> Object Bucket Claims
            - Create ObjectBucketClaim
              - Claim Name: *loki*
              - StorageClass: *openshift-storage.nooba.io*
              - BucketClass: *nooba-default-bucket-class*
          
          - CLI with [YAML](manifests/loki-odf-bucket.yaml)
            
            ```bash
            oc create -f manifests/loki-odf-bucket.yaml
            ```
            
        - Retrieve configuration into environment variables

          ```bash
          S3_BUCKET=$(oc get ObjectBucketClaim loki -n openshift-storage -o jsonpath='{.spec.bucketName}')
          REGION="''"
          ACCESS_KEY_ID=$(oc get secret loki -n openshift-storage -o jsonpath='{.data.AWS_ACCESS_KEY_ID}'|base64 -d)
          SECRET_ACCESS_KEY=$(oc get secret loki -n openshift-storage -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}'|base64 -d)
          ENDPOINT="https://s3.openshift-storage.svc:443"
          DEFAULT_STORAGE_CLASS=$(oc get sc -A -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
          ```
    - If you want to test with existing S3 bucket used by OpenShift Image Registry 
      
      ```bash
      S3_BUCKET=$(oc get configs.imageregistry.operator.openshift.io/cluster -o jsonpath='{.spec.storage.s3.bucket}' -n openshift-image-registry)
      REGION=$(oc get configs.imageregistry.operator.openshift.io/cluster -o jsonpath='{.spec.storage.s3.region}' -n openshift-image-registry)
      ACCESS_KEY_ID=$(oc get secret image-registry-private-configuration -o jsonpath='{.data.credentials}' -n openshift-image-registry|base64 -d|grep aws_access_key_id|awk -F'=' '{print $2}'|sed 's/^[ ]*//')
      SECRET_ACCESS_KEY=$(oc get secret image-registry-private-configuration -o jsonpath='{.data.credentials}' -n openshift-image-registry|base64 -d|grep aws_secret_access_key|awk -F'=' '{print $2}'|sed 's/^[ ]*//')
      ENDPOINT=$(echo "https://s3.$REGION.amazonaws.com")
      DEFAULT_STORAGE_CLASS=$(oc get sc -A -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
       ```

  - Create [Logging and Loki Instances](manifests/logging-loki-instance.yaml)
    
    ```bash
    cat manifests/logging-loki-instance.yaml \
        |sed 's/S3_BUCKET/'$S3_BUCKET'/' \
        |sed 's/REGION/'$REGION'/' \
        |sed 's|ACCESS_KEY_ID|'$ACCESS_KEY_ID'|' \
        |sed 's|SECRET_ACCESS_KEY|'$SECRET_ACCESS_KEY'|' \
        |sed 's|ENDPOINT|'$ENDPOINT'|'\
        |sed 's|DEFAULT_STORAGE_CLASS|'$DEFAULT_STORAGE_CLASS'|' \
        |oc apply -f -
    watch oc get po -n openshift-logging
    ```
    
    Output

    ```bash
    secret/logging-loki-s3 created
    lokistack.loki.grafana.com/logging-loki created
    clusterlogging.logging.openshift.io/instance created
    
    NAME                                          READY   STATUS    RESTARTS   AGE
    cluster-logging-operator-55c4c68fbf-79nkz     1/1     Running   0          10m
    collector-42nzt                               1/1     Running   0          4m32s
    collector-pd9mx                               1/1     Running   0          4m32s
    collector-snjm5                               1/1     Running   0          4m32s
    collector-trtz8                               1/1     Running   0          4m32s
    logging-loki-compactor-0                      1/1     Running   0          4m43s
    logging-loki-distributor-84b75dd686-n2d88     1/1     Running   0          4m43s
    logging-loki-distributor-84b75dd686-v48z2     1/1     Running   0          4m43s
    logging-loki-gateway-856d5d4cc8-g72wq         2/2     Running   0          4m42s
    logging-loki-gateway-856d5d4cc8-nsfpt         2/2     Running   0          4m42s
    logging-loki-index-gateway-0                  1/1     Running   0          4m43s
    logging-loki-index-gateway-1                  1/1     Running   0          4m12s
    logging-loki-ingester-0                       1/1     Running   0          4m43s
    logging-loki-ingester-1                       1/1     Running   0          3m28s
    logging-loki-ingester-2                       1/1     Running   0          2m14s
    logging-loki-querier-559bcc946b-p78bc         1/1     Running   0          4m43s
    logging-loki-querier-559bcc946b-ws7m2         1/1     Running   0          4m43s
    logging-loki-query-frontend-5fb4984f5-9cxg8   1/1     Running   0          4m43s
    logging-loki-query-frontend-5fb4984f5-r4fdr   1/1     Running   0          4m43s
    logging-loki-ruler-0                          1/1     Running   0          4m42s
    logging-loki-ruler-1                          1/1     Running   0          4m42s
    ```
- PVC storage (RWO) used by Loki (910 GiB)

  ```bash
  NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
  storage-logging-loki-compactor-0       Bound    pvc-20bf11d6-4c2f-4bd5-afad-7ce2114ae5de   10Gi       RWO            gp3-csi        <unset>                 5m30s
  storage-logging-loki-index-gateway-0   Bound    pvc-c1ae8654-3470-4d9a-88e4-280847b5c9ee   50Gi       RWO            gp3-csi        <unset>                 5m30s
  storage-logging-loki-index-gateway-1   Bound    pvc-41c42ec0-99f2-4fc1-bb97-4e785b249357   50Gi       RWO            gp3-csi        <unset>                 4m59s
  storage-logging-loki-ingester-0        Bound    pvc-458815dd-0021-4292-be24-b788a0643481   10Gi       RWO            gp3-csi        <unset>                 5m30s
  storage-logging-loki-ingester-1        Bound    pvc-175cfcc9-79f5-493a-a68b-fe2b67afd852   10Gi       RWO            gp3-csi        <unset>                 4m15s
  storage-logging-loki-ingester-2        Bound    pvc-663fe50c-e33b-470e-a546-5435deb741ee   10Gi       RWO            gp3-csi        <unset>                 3m1s
  storage-logging-loki-ruler-0           Bound    pvc-97cb2b54-e869-487e-bb48-eb423898d9a2   10Gi       RWO            gp3-csi        <unset>                 5m29s
  storage-logging-loki-ruler-1           Bound    pvc-34204cd1-70e9-4baf-8deb-b08ffbda95d7   10Gi       RWO            gp3-csi        <unset>                 5m29s
  wal-logging-loki-ingester-0            Bound    pvc-ffbd00d7-2773-4c90-aadb-13e8dff99458   150Gi      RWO            gp3-csi        <unset>                 5m30s
  wal-logging-loki-ingester-1            Bound    pvc-82597a12-c380-442d-90e3-fa7c3a107fdf   150Gi      RWO            gp3-csi        <unset>                 4m15s
  wal-logging-loki-ingester-2            Bound    pvc-03847758-6180-4d1d-be52-a5ac613dbf03   150Gi      RWO            gp3-csi        <unset>                 3m1s
  wal-logging-loki-ruler-0               Bound    pvc-662cb6e9-5087-4d44-95c0-fe7f11232804   150Gi      RWO            gp3-csi        <unset>                 5m29s
  wal-logging-loki-ruler-1               Bound    pvc-61b91b65-308f-4dca-913f-4001155d9193   150Gi      RWO            gp3-csi        <unset>                 5m29s
  ```

- Install Cluster Observability Operator
  
  ```bash
  oc create -f manifests/cluster-observability-operator.yaml
  oc get csv -n openshift-operators
  ```

  Output
  
  ```bash
  namespace/openshift-cluster-observability-operator created
  operatorgroup.operators.coreos.com/openshift-cluster-observability-operator-4q99p created
  subscription.operators.coreos.com/cluster-observability-operator created
  NAME                                    DISPLAY                          VERSION   REPLACES                                PHASE
  cluster-logging.v6.2.3                  Red Hat OpenShift Logging        6.2.3     cluster-logging.v6.2.2                  Succeeded
  cluster-observability-operator.v1.2.0   Cluster Observability Operator   1.2.0     cluster-observability-operator.v1.1.1   Succeeded
  loki-operator.v6.2.3                    Loki Operator                    6.2.3     loki-operator.v6.2.2                    Succeeded
  ```

- Create [UI Plugin](manifests/ui-plugin-logging.yaml) for Logging
  
  ```bash
  oc create -f manifests/ui-plugin-logging.yaml 
  ```
  
<!-- - Enable Console Plugin Operator
  
  - Navigate to Administrator->Operators->Installed Opertors->Red Hat OpenShift Logging then Enable Console Plugin on the right menu
  
    ![](images/enable-logging-console-plugin.png)


  - Or using CLI
    
    Remark: If you already enable other console plugins then run only the 2nd command

    ```bash
    oc patch console.operator cluster \
    --type json -p '[{"op": "add", "path": "/spec/plugins", "value": []}]'
    oc patch console.operator cluster \
    --type json -p '[{"op": "add", "path": "/spec/plugins/-", "value": "logging-view-plugin"}]'
    ``` -->

<!-- - Restart console pod
         
  ```bash
  for pod in $(oc get po -l component=ui -n openshift-console --no-headers -o custom-columns='Name:.metadata.name,PHASE:.status.phase' |grep Running|awk '{print $1}')
  do
    oc delete po $pod -n openshift-console
  done
  ``` -->

- Verify that Logs menu is avaiable under Observe menu
  
  ![](images/openshift-console-logging-menu.png)


## Test with Sample Applications

- Deploy sample applications

  ```bash
  oc new-project ui
  oc new-project api
  oc create -f manifests/frontend.yaml -n ui
  oc create -f manifests/backend-v1.yaml -n api
  oc expose deployment/backend-v1 -n api
  oc set env deployment/frontend-v1 BACKEND_URL=http://backend-v1.api.svc:8080 -n ui
  oc set env deployment/frontend-v2 BACKEND_URL=http://backend-v1.api.svc:8080 -n ui
  oc set env deployment/backend-v1 APP_BACKEND=https://httpbin.org/status/201 -n api
  oc scale deployment/frontend-v1 --replicas=2 -n ui
  oc scale deployment/frontend-v2 --replicas=2 -n ui
  oc scale deployment/backend-v1 --replicas=3 -n api
  ```

  Application Flow

  ```mermaid
  graph TD;
    Client--> Route
    Route-->|Project ui|Frontend;
    Frontend--> |Project api|Backend;
    Backend-->|External App|https://httpbin.org/status/201
   
  ```

- Test sample app
  
  ```bash
  FRONTEND_URL=$(oc get route/frontend -o jsonpath='{.spec.host}' -n ui)
  curl -v https://$FRONTEND_URL
  ```

  Output

  ```bash
  Frontend version: v2 => [Backend: http://backend-v1.api.svc:8080, Response: 201, Body: Backend version:v1, Response:201, Host:backend-v1-b585d794d-pcw9k, Status:201, Message: Hello, World
  ```

- Check log 
  - Switch to Developer Console and choose project api
  - Select menu Observe -> Logs
    
    ![](images/loki-log-overall.png)
  
  - Filter log by Severity
    - Select Severity
      
      ![](images/loki-filter-log-by-severity.png)


      Output

      ![](images/loki-backend-log-info.png)
  
## Support for multi-lines error log
- Configure backend app to return 500
  
  ```bash
  oc set env deployment/backend-v1 APP_BACKEND=https://httpbin.org/status/500 -n api
  ```
- Test app
  
  ```bash
  curl -v https://$FRONTEND_URL
  ```

  Output

  ```bash
  < HTTP/1.1 500 Internal Server Error
  < x-correlation-id: 94235c71-c810-4894-b6fd-41517464060a
  < x-powered-by: Express
  < content-type: text/html; charset=utf-8
  < content-length: 88
  < etag: W/"58-ybUg4JCk2x6Hmz6hGWKXkVMOmdQ"
  < date: Thu, 04 Jan 2024 03:02:05 GMT
  < keep-alive: timeout=5
  < set-cookie: edf28febca8ee46e0446d33e418fb5c2=fc80b538e2fb152c86546fc1c0328e01; path=/; HttpOnly; Secure; SameSite=None
  <
  * Connection #0 to host frontend-ui.apps.cluster-xxx.io left intact
  Frontend version: v2 => [Backend: http://backend-v1.api.svc:8080, Response: 500, Body: ]
  ```
- Check log
  
  ![](images/loki-log-multiple-error-lines.png)

- Configure log forward with option [detectMultilineErrors](manifests/ClusterLogForwarder-detectMultilineErrors.yaml)

  ```bash
  oc create -f manifests/ClusterLogForwarder-detectMultilineErrors.yaml
  ```
- Test app again and check log in Loki
  
  ![](images/loki-log-single-error-line-01.png)

  detail

  ![](images/loki-log-single-error-line-02.png)


## LogQL
- Open Developer Console then select Observe->Log
- Click *Show Query* and input following LogQL to query
  - Application Log 
  - in namesapce *api*
  - only worker node name *ip-10-0-215-10.us-east-2.compute.internal*
  - and contain string *Return Code*
  
  *Remark: replace your worker node hostname to ip-10-0-215-10.us-east-2.compute.internal*

  ```bash
  { log_type="application", kubernetes_namespace_name="api" } | json | hostname=~"ip-10-0-215-10.us-east-2.compute.internal" |~ "Return Code: .*"
  ```

  Output

  ![](images/logQL-sample-query.png)



## Alert

- Label namespace api to match condition for LokiStack to monitor for alert
  
  ```bash
  oc label ns api openshift.io/cluster-monitoring=true
  ```

- [Optional] Add roles to user to manage alert (CRUD)
  
  ```bash
  oc adm policy add-role-to-user alertingrules.loki.grafana.com-v1-admin -n api user1
  ```

- Create [Alert Rule](manifests/loki-backend-alert.yaml)
  
  ```bash
  oc apply -f manifests/loki-backend-alert.yaml
  ```

- Configure backend app to return 500
  
  ```bash
  oc set env deployment/backend-v1 APP_BACKEND=https://httpbin.org/status/500 -n api
  ```
- Call frontend
- Check for alert
  
  ![](images/loki-backend-alert.png)


<!-- delete ingester then queier -->