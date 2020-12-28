# Infrastructure Basic

<!-- TOC -->

- [Infrastructure Basic](#infrastructure-basic)
  - [Prerequisites](#prerequisites)
  - [OpenShift RBAC with AD](#openshift-rbac-with-ad)
  - [OpenShift Mornitering and Alert](#openshift-mornitering-and-alert)
  - [OpenShift Cluster Logging](#openshift-cluster-logging)
  - [Backup etcd](#backup-etcd)
    - [Backing up etcd data](#backing-up-etcd-data)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 on VMware 6.7 U3+ or 7.0
- VMware Cloud Native Storage to support CNS CSI
- OpenShift installer
  - Node subnet with DHCP pool
  - DNS
  - NTP

## OpenShift RBAC with AD

## OpenShift Mornitering and Alert

## OpenShift Cluster Logging

## Backup etcd

etcd is the key-value store for OpenShift Container Platform, which persists the state of all resource objects.

Back up your cluster’s etcd data regularly and store in a secure location ideally outside the OpenShift Container Platform environment.

After you have an etcd backup, you can restore to a previous cluster state.

### Backing up etcd data

Follow these steps to back up etcd data by creating an etcd snapshot and backing up the resources for the static pods. This backup can be saved and used at a later time if you need to restore etcd.

Prerequisites
- You have access to the cluster as a user with the cluster-admin role.
- You have checked whether the cluster-wide proxy is enabled.

Procedure
- Start a debug session for a master node:
  ```
  $ oc debug node/<node_name>
  ```
- Change your root directory to the host:
  ```
  sh-4.2# chroot /host
  ```
- If the cluster-wide proxy is enabled, be sure that you have exported the NO_PROXY, HTTP_PROXY, and HTTPS_PROXY environment variables.
- Run the cluster-backup.sh script and pass in the location to save the backup to.
  ```
  sh-4.4# /usr/local/bin/cluster-backup.sh /home/core/assets/backup
  ```

  Example script output
  ```
  1bf371f1b5a483927cd01bb593b0e12cff406eb8d7d0acf4ab079c36a0abd3f7
  etcdctl version: 3.3.18
  API version: 3.3
  found latest kube-apiserver-pod: /etc/kubernetes/static-pod-resources/kube-apiserver-pod-7
  found latest kube-controller-manager-pod: /etc/kubernetes/static-pod-resources/kube-controller-manager-pod-8
  found latest kube-scheduler-pod: /etc/kubernetes/static-pod-resources/kube-scheduler-pod-6
  found latest etcd-pod: /etc/kubernetes/static-pod-resources/etcd-pod-2
  Snapshot saved at /home/core/assets/backup/snapshot_2020-03-18_220218.db
  snapshot db and kube resources are successfully saved to /home/core/assets/backup
  ```

  In this example, two files are created in the /home/core/assets/backup/ directory on the master host:

  - snapshot_<datetimestamp>.db: This file is the etcd snapshot.
  - static_kuberesources_<datetimestamp>.tar.gz: This file contains the resources for the static pods. If etcd encryption is enabled, it also contains the encryption keys for the etcd snapshot.