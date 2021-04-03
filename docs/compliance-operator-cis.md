# OpenShift CIS Compliance with Compliance Operator

<!-- TOC -->

- [OpenShift CIS Compliance with Compliance Operator](#openshift-cis-compliance-with-compliance-operator)
    - [Prerequisites](#prerequisites)
    - [CIS Compliance](#cis-compliance)
    - [Compliance Operator](#compliance-operator)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 or 4.7
- Cluster-admin user access

## CIS Compliance

The Kubernetes Container Platform has been long managed Storage Driver in-tree to support vSphere Volume Driver, EBS, Azure Disk, etc. Now the persistence storage requirements are expanding to support more external storage operation like snapshot, volume expansion or migration, so the Container Storage Interface is the standard container storage interface for integration with external storage provider https://kubernetes-csi.github.io/docs/introduction.html.

## Compliance Operator

After the infrastucture met minimum requirements (vSphere 6.7U3), this is the high level process to install vSphere CSI on OpenShift Container Platform

1. Create Compliance Operator source and subscription
2. Create ComplianceScan
3. How to check Reports and Remediation

Steps:

1. 