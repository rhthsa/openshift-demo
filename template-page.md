# Your Topic

<!-- TOC -->

- [Your Topic](#your-topic)
    - [Prerequisites](#prerequisites)
    - [Introduction](#introduction)
    - [What you are going to do](#what-you-are-going-to-do)
    - [Steps 1-2-3](#steps-1-2-3)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 or 4.7
- Cluster-admin user access
- Your Pre-requisites

## Introduction

The Kubernetes Container Platform has been long managed Storage Driver in-tree to support vSphere Volume Driver, EBS, Azure Disk, etc. Now the persistence storage requirements are expanding to support more external storage operation like snapshot, volume expansion or migration, so the Container Storage Interface is the standard container storage interface for integration with external storage provider https://kubernetes-csi.github.io/docs/introduction.html.

## What you are going to do

After the infrastucture met minimum requirements (vSphere 6.7U3), this is the high level process to install vSphere CSI on OpenShift Container Platform

1. Create Compliance Operator source and subscription
2. Create ComplianceScan
3. How to check Reports and Remediation

Sample picture
![your sample picture](images/service-mesh-sample-app.png)

## Steps 1-2-3

Steps:

- a
- b
  - c
- d

Code Block

```bash
uname -a
```

```yaml
---
sample: yaml
spec:
  key1: value1
  item_list:
    - name: item1
      property: prop1
    - name: item2
      property: prop2
```

Sample inline yaml to oc apply

```bash
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