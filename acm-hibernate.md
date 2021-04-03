# RHACM Hibernate OpenShift on Cloud Providers for Cost Saving

<!-- TOC -->

- [RHACM Hibernate OpenShift on Cloud Providers for Cost Saving](#rhacm-hibernate-openshift-on-cloud-providers-for-cost-saving)
  - [Prerequisites](#prerequisites)
  - [Introduction](#introduction)
  - [How ACM acheive Hibernate policies for OpenShift](#how-acm-acheive-hibernate-policies-for-openshift)
  - [Steps 1-2-3](#steps-1-2-3)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 or 4.7
- Cluster-admin user access
- Red Hat Advanced Cluster Management
- Cloud Provider Credentials

## Introduction

Original article from [Hibernate for cost savings for Advanced Cluster Management Provisioned Clusters with Subscriptions](https://www.openshift.com/blog/hibernate-for-cost-savings-for-advanced-cluster-management-provisioned-clusters-with-subscriptions)

OpenShift 4 has the ability to suspend and resume clusters on Cloud Providers. Red Hat Advanced Cluster Management extends this capability through its Cluster Lifecycle Management (Hive), where you can have a policy to hibernate the clusters to save the cost saving in non-working hours (ex. 16 hours in a day is 16/24 = 66% saving)

## How ACM acheive Hibernate policies for OpenShift

We will walkthrough high-level process how ACM can define the herbernate policy for the cluster on Clouds

1. Clone the cluster-hibernate repository to your environment
2. Create the Running/Hibernate manifest files and put them in your Channel
3. Create the Subscription to local hub cluster with your desire time windows

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