# Cluster Metering and Cost Management

<!-- TOC -->

- [Cluster Metering and Cost Management](#cluster-metering-and-cost-management)
  - [Prerequisites](#prerequisites)
  - [Metering](#metering)
    - [Deploy Minio via Helm Chart](#deploy-minio-via-helm-chart)
  - [Cost Management](#cost-management)
    - [Cost Manager on cloud.redhat.com](#cost-manager-on-cloudredhatcom)
    - [Adding and OpenShift source to cost management](#adding-and-openshift-source-to-cost-management)
    - [Install Metering Operator](#install-metering-operator)
      - [Install Metering Stack](#install-metering-stack)
      - [Cost Management Operator](#cost-management-operator)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 on VMware 6.7 U3+ or 7.0
- VMware Cloud Native Storage to support CNS CSI

Metering requires the following components:

- A StorageClass for dynamic volume provisioning. Metering supports a number of different storage solutions.
- Metering requires persistent storage to persist data collected by the metering-operator and to store the results of reports. A number of different storage providers and storage formats are supported, please see the list below.
  - S3 compatible storage (recommended)
  - Storing data in shared ReadWriteMany PersistentVolume (NFS is not recommended to use with metering)
- 4GB memory and 4 CPU cores available cluster capacity and at least one node with 2 CPU cores and 2GB memory capacity available. 
- The minimum resources needed for the largest single Pod installed by metering are 2GB of memory and 2 CPU cores.
  - Memory and CPU consumption may often be lower, but will spike when running reports, or collecting data for larger clusters.

## Metering

Metering is a general purpose data analysis tool that enables you to write reports to process data from different data sources. As a cluster administrator, you can use metering to analyze what is happening in your cluster. You can either write your own, or use predefined SQL queries to define how you want to process data from the different data sources you have available.

Metering focuses primarily on in-cluster metric data using Prometheus as a default data source, enabling users of metering to do reporting on pods, namespaces, and most other Kubernetes resources.

### Deploy Minio via Helm Chart

For this demo, we will use Minio to provide S3 bucket for metering and cost management data repository. The Minio instance will be created from Helm Chart to OpenShift Cluster

**Procedures**

- Download and install `helm` binary
  ```
  curl -L https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/helm-linux-amd64 -o /usr/local/bin/helm
  chmod +x /usr/local/bin/helm
  helm version
  ```
- Install Minio via Helm 3
  ```
  oc new-project minio-tenant-1
  helm repo add minio https://helm.min.io/
  helm install --namespace minio-tenant-1 --generate-name minio/minio --set accessKey=minio,secretKey=minio123
  ```

- Expose the Minio via OpenShift Route
  ```
  export MINIO_SVC=$(oc -n minio-tenant-1 get svc | grep minio | cut -d' ' -f 1)
  oc expose svc/$MINIO_SVC

  export MINIO_ROUTE=$(oc get route $MINIO_SVC -ojsonpath="{.spec.host}")
  echo $MINIO_ROUTE
  ```

- Install Minio Client to interact with Minio deployment
  On Linux
  ```
  wget https://dl.min.io/client/mc/release/linux-amd64/mc
  chmod +x mc
  mv mc /usr/local/bin/
  ./mc --help
  ```
- Set Minio endpoint and username and password
  ```
  export MINIOUSR=minio
  export MINIOPWD=minio123
  mc alias set minio http://$MINIO_ROUTE "$ACCESS_KEY" "$SECRET_KEY" --api s3v4
  ```

- Create a bucket name `ocp-metering`
  ```
  mc mb minio/ocp-metering
  ```

- List newly create bucket
  ```
  mc ls minio
  ```

## Cost Management

### Cost Manager on cloud.redhat.com

Cost Management WebUI and API is on cloud.redhat.com, you can
- add Cost Management Role to Groups/Users
- View Cost Management reports

### Adding and OpenShift source to cost management

To add OCP as source from Cost Management Oprator

1. Install the Cost Management Operator in OpenShift from OperatorHub
2. Configure Cost Management to collect metrics
3. Provide the cluster identifier to costmanagement in cloud.redhat.com

### Install Metering Operator

- In the OpenShift Container Platform web console, click Administration → Namespaces → Create Namespace.
- Set the name to openshift-metering. No other namespace is supported. Label the namespace with openshift.io/cluster-monitoring=true, and click Create.
- OperatorHub > Search "metering"
- Install > Create Operator Subscription > ensure Installed Namespace = "openshift-metering"
- OperatorHub > Search "cost management"
- Install > Create Operator Subscription > ensure Installed Namespace = "openshift-metering"

#### Install Metering Stack

We will create a Metering Stack that including Hive and Presto that Query cluster metrics and create a report for metering usage. The data is stored in Minio bucket created in previous step. Note: we will reduce Deployment/Statefulset resource request for lab purpose.

```
cat <<EOF | oc -n openshift-metering create -f -
---
apiVersion: metering.openshift.io/v1
kind: MeteringConfig
metadata:
  name: "operator-metering"
  namespace: "openshift-metering"
spec:
  storage:
    type: "hive"
    hive:
      type: "s3Compatible"
      s3Compatible:
        bucket: "ocp-metering"
        endpoint: "http://$MINIO_ROUTE" 
        secretName: "metering-minio-secret"
  hive:
    spec:
      metastore:
        storage:
          # Default is null, which means using the default storage class if it exists.
          # If you wish to use a different storage class, specify it here
          # class: "null" 
          size: "5Gi"
        resources:
          limits:
            cpu: 2
            memory: 2Gi
          requests:
            cpu: 100m
            memory: 300Mi
      server:
        resources:
          limits:
            cpu: 1
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 300Mi
  reporting-operator:
    spec:
      resources:
        limits:
          cpu: 1
          memory: 500Mi
        requests:
          cpu: 100m
          memory: 100Mi
  presto:
    spec:
      coordinator:
        resources:
          limits:
            cpu: 4
            memory: 4Gi
          requests:
            cpu: 100m
            memory: 300Mi
      worker:
        replicas: 0
        resources:
          limits:
            cpu: 8
            memory: 8Gi
          requests:
            cpu: 100m
            memory: 300Mi    
---
apiVersion: v1
kind: Secret
metadata:
  name: metering-minio-secret
data:
  aws-access-key-id: "bWluaW8="
  aws-secret-access-key: "bWluaW8xMjM="
EOF
```

#### Cost Management Operator

The Cost Management Operator instance is the Cost Management reporting tools that run Metering quesries and upload summarized data to the Cost Management on cloud.redhat.com

We will deploy Cost Management instance and then go back to check the Cost Management module on cloud.redhat.com

- Create the authentication secret that contain Pull-secret for cost management operator to use

  ```
  cat <<EOF | oc apply -n openshift-metering -f -
  ---
  kind: Secret
  apiVersion: v1
  metadata:
    name: auth-secret-metering
    namespace: openshift-metering
    annotations:
      kubernetes.io/service-account.name: cost-mgmt-operator
  data:
    token: >-
      $(oc -n openshift-config get secret pull-secret -o "jsonpath={.data.\.dockerconfigjson}" | base64 --decode | jq '.auths."cloud.openshift.com".auth' | base64 -w 0)
  EOF
  ```

- Create a CostManagement instance that includes Cluster ID, Reporting Operator token and Authentication secret

  ```
  cat <<EOF | oc create -f -
  apiVersion: cost-mgmt.openshift.io/v1alpha1
  kind: CostManagement
  metadata:
    name: cost-mgmt-setup
    namespace: openshift-metering
  spec:
    clusterID: "$(oc get clusterversion -o jsonpath='{.items[].spec.clusterID}{"\n"}')"
    reporting_operator_token_name: "$(oc get secret -n openshift-metering | grep reporting-operator-token | cut -d' ' -f1 | head -n 1)"
    validate_cert: 'false'
    authentication: 'token'
    authentication_secret_name: 'auth-secret-metering'
  EOF
  ```
  