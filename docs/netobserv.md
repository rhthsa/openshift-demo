# Network Observability
- [Network Observability](#network-observability)
  - [Install and Config](#install-and-config)

## Install and Config

- Config Loki
  - Prepare Object Storage configuration including S3 access Key ID, access Key Secret, Bucket Name, endpoint and Region
      - For demo purpose, If you have existing S3 bucket used by OpenShift Image Registry
        
        ```bash
          S3_BUCKET=$(oc get configs.imageregistry.operator.openshift.io/cluster -o jsonpath='{.spec.storage.s3.bucket}' -n openshift-image-registry)
          AWS_REGION=$(oc get configs.imageregistry.operator.openshift.io/cluster -o jsonpath='{.spec.storage.s3.region}' -n openshift-image-registry)
          AWS_ACCESS_KEY_ID=$(oc get secret image-registry-private-configuration -o jsonpath='{.data.credentials}' -n openshift-image-registry|base64 -d|grep aws_access_key_id|awk -F'=' '{print $2}'|sed 's/^[ ]*//')
          AWS_SECRET_ACCESS_KEY=$(oc get secret image-registry-private-configuration -o jsonpath='{.data.credentials}' -n openshift-image-registry|base64 -d|grep aws_secret_access_key|awk -F'=' '{print $2}'|sed 's/^[ ]*//')
         ```
  - Create [Loki Instance](manifests/netobserv-loki-s3.yaml)
  
    ```bash
        cat manifests/netobserv-loki-s3.yaml \
        |sed 's/S3_BUCKET/'$S3_BUCKET'/' \
        |sed 's/AWS_REGION/'$AWS_REGION'/' \
        |sed 's/AWS_ACCESS_KEY_ID/'$AWS_ACCESS_KEY_ID'/' \
        |sed 's|AWS_SECRET_ACCESS_KEY|'$AWS_SECRET_ACCESS_KEY'|' \
        |oc apply -f -
        watch oc get po -n netobserv
    ```

 
 - Install [Network Observability Operator](manifests/netobserv-operator.yaml)

  *Remark: Loki Operator is prerequistes of Network Observability Operator*

  ```bash
  oc create -f manifests/netobserv-operator.yaml
  oc wait --for condition=established --timeout=180s \
  crd/flowcollectors.flows.netobserv.io
  oc get csv -n openshift-netobserv-operator
  ```

 - Create [FlowCollector](manifests/FlowCollector.yaml)
    
   ```bash
   oc create -f manifests/FlowCollector.yaml
   ```

 - Check Network Observability by Open Administrator -> Observe -> Network Traffic
   
   Topology

  ![](images/network-observability-network-topology.png)