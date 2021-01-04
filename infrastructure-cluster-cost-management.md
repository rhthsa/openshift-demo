# Cluster Metering and Cost Management

<!-- TOC -->

- [Cluster Metering and Cost Management](#cluster-metering-and-cost-management)
  - [Prerequisites](#prerequisites)
  - [Metering](#metering)
    - [Create MinIO Operator](#create-minio-operator)
  - [Cost Management](#cost-management)
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

### Create MinIO Operator

For this demo, we will use Minio to provide S3 bucket for metering and cost management data repository

**Procedures**

- Subscribe Minio Operator (Community)
  ```
  oc new-project minio-operator
  oc apply -n minio-operator -f https://raw.githubusercontent.com/minio/minio-operator/master/minio-operator.yaml
  ```

- Create a MinIO instance
  Once MinIO-Operator deployment is running, you can create MinIO instances using the below command
  ```
  oc apply -f https://raw.githubusercontent.com/minio/minio-operator/master/examples/minioinstance.yaml
  ```

- Expose the Minio webui via OpenShift Route
  ```
  oc expose service minio-service
  oc get route
  export MINIOROUTE=$(oc get route | grep minio | cut -d' ' -f 2)
  ```

- Install Minio Client to interact with Minio deployment
  On Mac
  ```
  brew install minio/stable/mc
  ```

  On Linux
  ```
  ```
- Set Minio endpoint and username and password
  ```
  export MINIOUSR=minio
  export MINIOPWD=minio123
  mc config host add minio $MINIOROUTE minio minio123
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

### Install Metering Operator

- In the OpenShift Container Platform web console, click Administration → Namespaces → Create Namespace.
- Set the name to openshift-metering. No other namespace is supported. Label the namespace with openshift.io/cluster-monitoring=true, and click Create.
- OperatorHub > Search "metering"
- Install > Create Operator Subscription > ensure Installed Namespace = "openshift-metering"

#### Install Metering Stack

```
cat <<EOF | oc create -f -
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
        endpoint: "$MINIOROUTE" 
        secretName: "metering-minio-secret"
  hive:
    spec:
      metastore:
        storage:
          # Default is null, which means using the default storage class if it exists.
          # If you wish to use a different storage class, specify it here
          # class: "null" 
          size: "5Gi"
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

Operators > Installed Operators
Under Provided APIs > Create Instance 

#### Cost Management Operator

