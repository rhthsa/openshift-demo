# Infrastructure Basic

<!-- TOC -->

- [Infrastructure Basic](#infrastructure-basic)
    - [Prerequisites](#prerequisites)
    - [Backup etcd](#backup-etcd)
        - [Backing up etcd data](#backing-up-etcd-data)
        - [Restoring to a previous cluster state](#restoring-to-a-previous-cluster-state)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 on VMware 6.7 U3+ or 7.0
- VMware Cloud Native Storage to support CNS CSI
- OpenShift installer
  - Node subnet with DHCP pool
  - DNS
  - NTP

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
  oc debug node/<node_name>
  ```
- Change your root directory to the host:
  ```
  chroot /host
  ```
- If the cluster-wide proxy is enabled, be sure that you have exported the ``NO_PROXY``, ``HTTP_PROXY``, and ``HTTPS_PROXY`` environment variables.
- Run the cluster-backup.sh script and pass in the location to save the backup to.
  ```
  /usr/local/bin/cluster-backup.sh /home/core/assets/backup
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

### Restoring to a previous cluster state

To restore the cluster to a previous state, you must have previously backed up etcd data by creating a snapshot. You will use this snapshot to restore the cluster state.

You can use a saved etcd backup to restore back to a previous cluster state. You use the etcd backup to restore a single control plane host. Then the etcd cluster Operator handles scaling to the remaining master hosts.

Prerequisites
- Access to the cluster as a user with the cluster-admin role.
- SSH access to master hosts.

A backup directory containing both the etcd snapshot and the resources for the static pods, which were from the same backup. The file names in the directory must be in the following formats: snapshot_<datetimestamp>.db and static_kuberesources_<datetimestamp>.tar.gz.

Procedure
- Select a control plane host to use as the recovery host. This is the host that you will run the restore operation on.
- Establish SSH connectivity to each of the control plane nodes, including the recovery host.
  The Kubernetes API server becomes inaccessible after the restore process starts, so you cannot access the control plane nodes. For this reason, it is recommended to establish SSH connectivity to each control plane host in a separate terminal.
  **Warning:** If you do not complete this step, you will not be able to access the master hosts to complete the restore procedure, and you will be unable to recover your cluster from this state.
- Copy the etcd backup directory to the recovery control plane host.
  This procedure assumes that you copied the backup directory containing the etcd snapshot and the resources for the static pods to the ``/home/core/`` directory of your recovery control plane host.
- Stop the static pods on all other control plane nodes.
  **Note:** It is not required to manually stop the pods on the recovery host. The recovery script will stop the pods on the recovery host.
  - Access a control plane host that is not the recovery host.
  - Move the existing etcd pod file out of the kubelet manifest directory:
    ```
    sudo mv /etc/kubernetes/manifests/etcd-pod.yaml /tmp
    ```
  - Verify that the etcd pods are stopped.
    ```
    sudo crictl ps | grep etcd
    ```
    The output of this command should be empty. If it is not empty, wait a few minutes and check again.

  - Move the existing Kubernetes API server pod file out of the kubelet manifest directory:
    ```
    sudo mv /etc/kubernetes/manifests/kube-apiserver-pod.yaml /tmp
    ```
  - Verify that the Kubernetes API server pods are stopped.
    ```
    sudo crictl ps | grep kube-apiserver
    ```
    The output of this command should be empty. If it is not empty, wait a few minutes and check again.
  - Move the etcd data directory to a different location:
    ```
    sudo mv /var/lib/etcd/ /tmp
    ```
  - Repeat this step on each of the other master hosts that is not the recovery host.
- Access the recovery control plane host.
- If the cluster-wide proxy is enabled, be sure that you have exported the NO_PROXY, HTTP_PROXY, and HTTPS_PROXY environment variables.
  You can check whether the proxy is enabled by reviewing the output of oc get proxy cluster -o yaml. The proxy is enabled if the httpProxy, httpsProxy, and noProxy fields have values set.
- Run the restore script on the recovery control plane host and pass in the path to the etcd backup directory:
  ```
  sudo -E /usr/local/bin/cluster-restore.sh /home/core/backup
  ```
  
  Example script output
  ```
  ...stopping kube-scheduler-pod.yaml
  ...stopping kube-controller-manager-pod.yaml
  ...stopping etcd-pod.yaml
  ...stopping kube-apiserver-pod.yaml
  Waiting for container etcd to stop
  .complete
  Waiting for container etcdctl to stop
  .............................complete
  Waiting for container etcd-metrics to stop
  complete
  Waiting for container kube-controller-manager to stop
  complete
  Waiting for container kube-apiserver to stop
  ..........................................................................................complete
  Waiting for container kube-scheduler to stop
  complete
  Moving etcd data-dir /var/lib/etcd/member to /var/lib/etcd-backup
  starting restore-etcd static pod
  starting kube-apiserver-pod.yaml
  static-pod-resources/kube-apiserver-pod-7/kube-apiserver-pod.yaml
  starting kube-controller-manager-pod.yaml
  static-pod-resources/kube-controller-manager-pod-7/kube-controller-manager-pod.yaml
  starting kube-scheduler-pod.yaml
  static-pod-resources/kube-scheduler-pod-8/kube-scheduler-pod.yaml
  ```

- Restart the kubelet service on all master hosts.
  - From the recovery host, run the following command:
    ```
    sudo systemctl restart kubelet.service
    ```
  - Repeat this step on all other master hosts.
- Verify that the single member control plane has started successfully.
  - From the recovery host, verify that the etcd container is running.
    ```
    sudo crictl ps | grep etcd
    ```
    
    Example output
    ```
    3ad41b7908e32       36f86e2eeaaffe662df0d21041eb22b8198e0e58abeeae8c743c3e6e977e8009                                                         About a minute ago   Running             etcd                                          0                   7c05f8af362f0
    ```

  - From the recovery host, verify that the etcd pod is running.
    ```
    oc get pods -n openshift-etcd | grep etcd
    ```
    Example output
    ```
    NAME                                             READY   STATUS      RESTARTS   AGE
    etcd-ip-10-0-143-125.ec2.internal                1/1     Running     1          2m47s
    ```
    If the status is Pending, or the output lists more than one running etcd pod, wait a few minutes and check again.

- Force etcd redeployment.
  In a terminal that has access to the cluster as a cluster-admin user, run the following command:
  ```
  oc patch etcd cluster -p='{"spec": {"forceRedeploymentReason": "recovery-'"$( date --rfc-3339=ns )"'"}}' --type=merge
  ```
  The forceRedeploymentReason value must be unique, which is why a timestamp is appended.
  When the etcd cluster Operator performs a redeployment, the existing nodes are started with new pods similar to the initial bootstrap scale up.

- Verify all nodes are updated to the latest revision.

  In a terminal that has access to the cluster as a cluster-admin user, run the following command:
  ```
  oc get etcd -o=jsonpath='{range .items[0].status.conditions[?(@.type=="NodeInstallerProgressing")]}{.reason}{"\n"}{.message}{"\n"}'
  ```
  Review the ``NodeInstallerProgressing`` status condition for etcd to verify that all nodes are at the latest revision. The output shows ``AllNodesAtLatestRevision`` upon successful update:
  ```
  AllNodesAtLatestRevision
  3 nodes are at revision 3
  ```
  If the output shows a message such as 2 nodes are at revision 3; 1 nodes are at revision 4, this means that the update is still in progress. Wait a few minutes and try again.

- After etcd is redeployed, force new rollouts for the control plane. The Kubernetes API server will reinstall itself on the other nodes because the kubelet is connected to API servers using an internal load balancer.

In a terminal that has access to the cluster as a cluster-admin user, run the following commands.

  - Update the kubeapiserver:
    ```
    oc patch kubeapiserver cluster -p='{"spec": {"forceRedeploymentReason": "recovery-'"$( date --rfc-3339=ns )"'"}}' --type=merge
    ```
    
    Verify all nodes are updated to the latest revision.
    ```
    oc get kubeapiserver -o=jsonpath='{range .items[0].status.conditions[?(@.type=="NodeInstallerProgressing")]}{.reason}{"\n"}{.message}{"\n"}'
    ```
    Review the ``NodeInstallerProgressing`` status condition to verify that all nodes are at the latest revision. The output shows ``AllNodesAtLatestRevision`` upon successful update:
    
    ```
    AllNodesAtLatestRevision
    3 nodes are at revision 3
    ```

  - Update the kubecontrollermanager:
    
    ```
    oc patch kubecontrollermanager cluster -p='{"spec": {"forceRedeploymentReason": "recovery-'"$( date --rfc-3339=ns )"'"}}' --type=merge
    ```
    
    Verify all nodes are updated to the latest revision.
    ```
    oc get kubecontrollermanager -o=jsonpath='{range .items[0].status.conditions[?(@.type=="NodeInstallerProgressing")]}{.reason}{"\n"}{.message}{"\n"}'
    ```

    Review the ``NodeInstallerProgressing`` status condition to verify that all nodes are at the latest revision. The output shows ``AllNodesAtLatestRevision`` upon successful update:
    
    ```
    AllNodesAtLatestRevision
    3 nodes are at revision 3
    ```

  - Update the kubescheduler:
    
    ```
    oc patch kubescheduler cluster -p='{"spec": {"forceRedeploymentReason": "recovery-'"$( date --rfc-3339=ns )"'"}}' --type=merge
    ```
    Verify all nodes are updated to the latest revision.
    
    ```
    oc get kubescheduler -o=jsonpath='{range .items[0].status.conditions[?(@.type=="NodeInstallerProgressing")]}{.reason}{"\n"}{.message}{"\n"}'
    ```
    
    Review the ``NodeInstallerProgressing`` status condition to verify that all nodes are at the latest revision. The output shows ``AllNodesAtLatestRevision`` upon successful update:
    
    ```
    AllNodesAtLatestRevision
    3 nodes are at revision 3
    ```

- Verify that all master hosts have started and joined the cluster.

  In a terminal that has access to the cluster as a cluster-admin user, run the following command:

  ```
  oc get pods -n openshift-etcd | grep etcd
  ```

  Example output
  ```
  etcd-ip-10-0-143-125.ec2.internal                2/2     Running     0          9h
  etcd-ip-10-0-154-194.ec2.internal                2/2     Running     0          9h
  etcd-ip-10-0-173-171.ec2.internal                2/2     Running     0          9h
  ```