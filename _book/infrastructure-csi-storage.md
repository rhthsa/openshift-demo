# OpenShift CSI Storage

<!-- TOC -->

- [OpenShift CSI Storage](#openshift-csi-storage)
    - [Prerequisites](#prerequisites)
    - [vSphere CSI](#vsphere-csi)
    - [vSphere CSI installation](#vsphere-csi-installation)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 on VMware 6.7 U3+ or 7.0
- VM compatibility version 15
- VMware Storage Policy for using as the StorageClass backend

## vSphere CSI

The Kubernetes Container Platform has been long managed Storage Driver in-tree to support vSphere Volume Driver, EBS, Azure Disk, etc. Now the persistence storage requirements are expanding to support more external storage operation like snapshot, volume expansion or migration, so the Container Storage Interface is the standard container storage interface for integration with external storage provider https://kubernetes-csi.github.io/docs/introduction.html.

## vSphere CSI installation

After the infrastucture met minimum requirements (vSphere 6.7U3), this is the high level process to install vSphere CSI on OpenShift Container Platform

1. Create vsphere config secret for csi driver to authenticate with permission needed for vsphere csi driver. The vSphere Roles and Privileges requirements can be check on [the vsphere csi driver documentations](https://vsphere-csi-driver.sigs.k8s.io/driver-deployment/prerequisites.html).
2. Create RBAC roles, service account, rolebinding and security context contraints
3. Create vSphere CSI Controller and daemonset

This article is reference from this following blog https://veducate.co.uk/how-to-install-vsphere-csi-driver-openshift/.

Steps:

1. 