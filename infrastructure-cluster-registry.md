# Cluster Metering and Cost Management

<!-- TOC -->

- [Cluster Metering and Cost Management](#cluster-metering-and-cost-management)
  - [Prerequisites](#prerequisites)
  - [OpenShift Internal Registry for vSphere](#openshift-internal-registry-for-vsphere)
  - [OpenShift External Registry](#openshift-external-registry)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 on VMware 6.7 U3+ or 7.0
- VMware Cloud Native Storage to support CNS CSI

## OpenShift Internal Registry for vSphere

After you install the cluster, you must create storage for the registry Operator.

For VMware environement, we usually don't have Object Storage available for Registry, so we will use RWO PV storage for single registry instance here

Procedure

1. Create `image-registry-storage` PVC. The example use default `thin` storageclass, please change per strageclass available in your environment.
    ```
    cat <<EOF | oc create -f -
    kind: PersistentVolumeClaim
    apiVersion: v1
    metadata:
      name: image-registry-storage
      namespace: openshift-image-registry
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 100Gi
      storageClassName: thin
      volumeMode: Filesystem
    EOF
    ```
2. Apply block registry storage for VMware vSphere
    ```
    oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","rolloutStrategy":"Recreate","storage":{"pvc":{"claim":"image-registry-storage"}}}}'
    ```

## OpenShift External Registry


