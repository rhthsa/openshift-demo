# Cost Management and Advanced Cluster Management Lab Notes

## Cost Management
TO DO 
- Add OCP Cluster as Sources in cloud.redhat.com 
- Install OpenShift Metering 
- Install OpenShift Cost Management Operator


### Metering

Metering is a general purpose data analysis tool that enables you to write reports to process data from different data sources. As a cluster administrator, you can use metering to analyze what is happening in your cluster. You can either write your own, or use predefined SQL queries to define how you want to process data from the different data sources you have available.

Metering focuses primarily on in-cluster metric data using Prometheus as a default data source, enabling users of metering to do reporting on pods, namespaces, and most other Kubernetes resources.

### Prerequisites

Metering requires the following components:

- A StorageClass for dynamic volume provisioning. Metering supports a number of different storage solutions.
- Metering requires persistent storage to persist data collected by the metering-operator and to store the results of reports. A number of different storage providers and storage formats are supported, please see the list below.
  - S3 compatible storage (recommended)
  - Storing data in shared ReadWriteMany PersistentVolume (NFS is not recommended to use with metering)
- 4GB memory and 4 CPU cores available cluster capacity and at least one node with 2 CPU cores and 2GB memory capacity available. 
- The minimum resources needed for the largest single Pod installed by metering are 2GB of memory and 2 CPU cores.
  - Memory and CPU consumption may often be lower, but will spike when running reports, or collecting data for larger clusters.

Steps

### Create MinIO Operator

oc new-project minio-operator
oc apply -n minio-operator -f https://raw.githubusercontent.com/minio/minio-operator/master/minio-operator.yaml

Create a MinIO instance
Once MinIO-Operator deployment is running, you can create MinIO instances using the below command

oc apply -f https://raw.githubusercontent.com/minio/minio-operator/master/examples/minioinstance.yaml

Expose MinIO via OpenShift Route

oc expose service minio-service

oc get route

Get Minio AccessKey and SecretKey

brew install minio/stable/mc

mc config host add minio http://minio-service-minio-operator.apps.cluster-bkk20-efc3.bkk20-efc3.example.opentlc.com minio minio123

mc mb minio/ocp-metering

mc ls minio

### Cost Management

#### Install Metering Operator

In the OpenShift Container Platform web console, click Administration → Namespaces → Create Namespace.

Set the name to openshift-metering. No other namespace is supported. Label the namespace with openshift.io/cluster-monitoring=true, and click Create.

OperatorHub > Search "metering"

Install > Create Operator Subscription > ensure Installed Namespace = "openshift-metering"

#### Install Metering Stack

oc create -f metering-minio-storage.yaml -n openshift-metering

Operators > Installed Operators
Under Provided APIs > Create Instance 

#### Cost Management Operator





## Advanced Cluster Management

### Install ACM

Create 'open-cluster-management' namespace
```shell
oc create namespace open-cluster-management
oc project open-cluster-management
```

Create OperatorGroup and Subscription for ACM

```shell
# Create open-cluster-management OperatorGroup from stdin
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: open-cluster-management-ggpkb
  namespace: open-cluster-management
spec:
  targetNamespaces:
  - open-cluster-management
EOF

```

```shell
# Create open-cluster-management OperatorGroup from stdin
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: advanced-cluster-management
  namespace: open-cluster-management
spec:
  channel: release-1.0
  installPlanApproval: Automatic
  name: advanced-cluster-management
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: advanced-cluster-management.v1.0.0
EOF

```

Create MulticlusterHub instance

```shell
cat <<EOF | oc apply -f -
apiVersion: operators.open-cluster-management.io/v1beta1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: open-cluster-management
spec: {}
EOF

```

Get Multicloud-console ui from route

```shell
watch oc -n open-cluster-management get route multicloud-console
```

Wait for installation to be finished
```shell
oc -n open-cluster-management get deploy -o name | grep consoleui
```

Enable baremetal in ACM 1.0 TP

```shell
MY_CONSOLEUI=`oc -n open-cluster-management get deploy -o name | grep consoleui`
oc -n open-cluster-management patch $MY_CONSOLEUI --patch '{"spec": {"template": {"spec": {"containers": [{"name": "hcm-ui", "env": [{"name": "featureFlags_baremetal", "value": "true"}]}]}}}}'

MY_HEADER=`oc -n open-cluster-management get deploy -o name | grep header`
oc -n open-cluster-management patch $MY_HEADER --patch '{"spec": {"template": {"spec": {"containers": [{"name": "console-header", "env": [{"name": "featureFlags_baremetal", "value": "true"}]}]}}}}'
```


