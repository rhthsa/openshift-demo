# OpenShift Infrastructure Nodes

<!-- TOC -->

- [OpenShift Infrastructure Nodes](#openshift-infrastructure-nodes)
    - [Prerequisites](#prerequisites)
    - [OpenShift Infrastructure Nodes](#openshift-infrastructure-nodes)
    - [OpenShift MachineSet](#openshift-machineset)
    - [Defining a Custom MachineSet](#defining-a-custom-machineset)
        - [Logging](#logging)
    - [Machine Config](#machine-config)
        - [MachineConfig overview](#machineconfig-overview)
        - [Checking Machine Config Pool status](#checking-machine-config-pool-status)

<!-- /TOC -->

## Prerequisites
- OpenShift 4.6 on VMware 6.7 U3+ or 7.0
- VMware Cloud Native Storage to support CNS CSI
- Resources enough to provision 3 infra nodes e.g. 4vCPU, 16GB RAM per node

## OpenShift Infrastructure Nodes
The OpenShift subscription model allows customers to run various core infrastructure components at no additional charge. In other words, a node that is only running core OpenShift infrastructure components is not counted in terms of the total number of subscriptions required to cover the environment.

OpenShift components that fall into the infrastructure categorization include:

- kubernetes and OpenShift control plane services ("masters")
- router
- container image registry
- cluster metrics collection ("monitoring")
- cluster aggregated logging
- service brokers

Any node running a container/pod/component not described above is considered a worker and must be covered by a subscription.

## OpenShift MachineSet

In the case of an infrastructure node, we want to create additional Machines that have specific Kubernetes labels. Then, we can configure the various infrastructure components to run specifically on nodes with those labels.

To accomplish this, you will create additional MachineSets.

In order to understand how MachineSets work, run the following.

This will allow you to follow along with some of the following discussion.

```
oc get machineset -n openshift-machine-api -o yaml $(oc get machineset -n openshift-machine-api | grep worker | cut -d' ' -f 1)
```

Sample Output

```
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: "2020-12-28T05:02:31Z"
  generation: 3
  labels:
    machine.openshift.io/cluster-api-cluster: ocp01-7k4c4
  name: ocp01-7k4c4-worker
  namespace: openshift-machine-api
  resourceVersion: "799241"
  selfLink: /apis/machine.openshift.io/v1beta1/namespaces/openshift-machine-api/machinesets/ocp01-7k4c4-worker
  uid: 52ad683d-99b6-423b-b045-4279f241640e
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ocp01-7k4c4
      machine.openshift.io/cluster-api-machineset: ocp01-7k4c4-worker
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: ocp01-7k4c4
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: ocp01-7k4c4-worker
    spec:
      metadata: {}
      providerSpec:
        value:
          apiVersion: vsphereprovider.openshift.io/v1beta1
          credentialsSecret:
            name: vsphere-cloud-credentials
          diskGiB: 120
          kind: VSphereMachineProviderSpec
          memoryMiB: 8192
          metadata:
            creationTimestamp: null
          network:
            devices:
            - networkName: VM Network
          numCPUs: 2
          numCoresPerSocket: 2
          snapshot: ""
          template: ocp01-7k4c4-rhcos
          userDataSecret:
            name: worker-user-data
          workspace:
            datacenter: dCloud-DC
            datastore: NFS_Datastore
            folder: /dCloud-DC/vm/ocp01-7k4c4
            resourcePool: /dCloud-DC/host/dCloud-Cluster/Resources
            server: vc1.dcloud.cisco.com
status:
  availableReplicas: 1
  fullyLabeledReplicas: 1
  observedGeneration: 3
  readyReplicas: 1
  replicas: 1
```

Important information in MachineSet

- Metadata
  The metadata on the MachineSet itself includes information like the name of the MachineSet and various labels.
- Selector
  The MachineSet defines how to create Machines, and the Selector tells the operator which machines are associated with the set
- Template Metadata
  The template is the part of the MachineSet that templates out the Machine. The template itself can have metadata associated, and we need to make sure that things match here when we make changes:
- Template Spec
  The template needs to specify how the Machine/Node should be created. You will notice that the spec and, more specifically, the providerSpec contains all of the important AWS data to help get the Machine created correctly and bootstrapped.

  In our case, we want to ensure that the resulting node inherits one or more specific labels. As you’ve seen in the examples above, labels go in metadata sections:

## Defining a Custom MachineSet

Now that you’ve analyzed an existing MachineSet it’s time to go over the rules for creating one, at least for a simple change like we’re making:

- Don’t change anything in the providerSpec
- Don’t change any instances of machine.openshift.io/cluster-api-cluster: <clusterid>
- Give your MachineSet a unique name
- Make sure any instances of machine.openshift.io/cluster-api-machineset match the name
- Add labels you want on the nodes to .spec.template.spec.metadata.labels
- Even though you’re changing MachineSet name references, be sure not to change the subnet.

This sounds complicated, but we have a template that will do the hard work for you:

```
export CLUSTERID=$(oc get machineset -n openshift-machine-api | grep worker | cut -d' ' -f 1 | sed 's/-worker//g')

cat <<EOF | oc create -f -
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: $CLUSTERID
  name: $CLUSTERID-infra
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: $CLUSTERID
      machine.openshift.io/cluster-api-machineset: $CLUSTERID-infra
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: $CLUSTERID
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: $CLUSTERID-infra
    spec:
      metadata:
        creationTimestamp: null
        labels:
          node-role.kubernetes.io/infra: ""
      providerSpec:
        value:
          apiVersion: vsphereprovider.openshift.io/v1beta1
          credentialsSecret:
            name: vsphere-cloud-credentials
          diskGiB: 120
          kind: VSphereMachineProviderSpec
          memoryMiB: 8192
          metadata:
            creationTimestamp: null
          network:
            devices:
            - networkName: VM Network
          numCPUs: 2
          numCoresPerSocket: 2
          snapshot: ""
          template: $CLUSTERID-rhcos
          userDataSecret:
            name: worker-user-data
          workspace:
            datacenter: dCloud-DC
            datastore: NFS_Datastore
            folder: /dCloud-DC/vm/$CLUSTERID
            resourcePool: /dCloud-DC/host/dCloud-Cluster/Resources
            server: vc1.dcloud.cisco.com
EOF
```

oc get machineset -n openshift-machine-api
You should see the new infra set listed with a name similar to the following:

```
ocp01-7k4c4-infra    1         1                             13s
```

We don’t yet have any ready or available machines in the set because the instances are still coming up and bootstrapping. You can check oc get machine -n openshift-machine-api to see when the instance finally starts running. Then, you can use oc get node to see when the actual node is joined and ready.

**Note:**
It can take several minutes for a Machine to be prepared and added as a Node.

```
oc get nodes
NAME                       STATUS   ROLES          AGE   VERSION
ocp01-7k4c4-infra-tz8w4    Ready    infra,worker   18m   v1.19.0+7070803
ocp01-7k4c4-master-0       Ready    master         2d    v1.19.0+7070803
ocp01-7k4c4-master-1       Ready    master         2d    v1.19.0+7070803
ocp01-7k4c4-master-2       Ready    master         2d    v1.19.0+7070803
ocp01-7k4c4-worker-wbq9b   Ready    worker         56m   v1.19.0+7070803
ocp01-7k4c4-worker-zw9w8   Ready    worker         2d    v1.19.0+7070803
```

If you’re having trouble figuring out which node is the new one, take a look at the AGE column. It will be the youngest! Also, in the ROLES column you will notice that the new node has both a worker and an infra role.

For the HA, we will need 3 infra nodes.

```
export $INFRAMS=$(oc get machineset -n openshift-machine-api | grep infra | cut -d' ' -f 1)
oc scale machineset $INFRAMS -n openshift-machine-api --replicas=3
```

Binding infrastructure node workloads using taints and tolerations

If you have an infra node that has the infra and worker roles assigned, you must configure the node so that user workloads are not assigned to it.

Use the following command to add a taint to the infra node to prevent scheduling user workloads on it:

```
for node in $(oc get nodes | grep infra | cut -d' ' -f 1 ); do
    oc adm taint nodes $node node-role.kubernetes.io/infra:NoSchedule
done
```

Check the Labels
We can ask what its labels are by using command:

```
oc get nodes --show-labels -l node-role.kubernetes.io/infra=
```

Output
```
NAME                      STATUS   ROLES          AGE   VERSION           LABELS
ocp01-7k4c4-infra-tz8w4   Ready    infra,worker   10m   v1.19.0+7070803   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ocp01-7k4c4-infra-tz8w4,kubernetes.io/os=linux,node-role.kubernetes.io/infra=,node-role.kubernetes.io/worker=,node.openshift.io/os_id=rhcos
```

##Moving Infrastructure Components

Now that you have infra nodes, it’s time to move various infrastructure components onto them.

###Router

The OpenShift router is managed by an Operator called openshift-ingress-operator. Its Pod lives in the openshift-ingress-operator project:

###Registry

The registry uses a similar CRD mechanism to configure how the operator deploys the actual registry pods. That CRD is configs.imageregistry.operator.openshift.io. You will edit the cluster CR object in order to add the nodeSelector

```
oc patch configs.imageregistry.operator.openshift.io/cluster -p '{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra": ""},"tolerations": [{"effect": "NoSchedule","key": "node-role.kubernetes.io/infra","operator": "Exists"}]}}' --type=merge
```

###Monitoring

The Cluster Monitoring operator is responsible for deploying and managing the state of the Prometheus+Grafana+AlertManager cluster monitoring stack. It is installed by default during the initial cluster installation. Its operator uses a ConfigMap in the openshift-monitoring project to set various tunables and settings for the behavior of the monitoring stack.

The following ConfigMap definition will configure the monitoring solution to be redeployed onto infrastructure nodes.

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |+
    alertmanagerMain:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusK8s:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusOperator:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    grafana:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    k8sPrometheusAdapter:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    kubeStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    telemeterClient:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
```

### Logging
OpenShift’s log aggregation solution is not installed by default. There is a dedicated lab exercise that goes through the configuration and deployment of logging.

## Machine Config

There are times when you need to make changes to the operating systems running on OpenShift Container Platform nodes. This can include changing settings for network time service, adding kernel arguments, or configuring journaling in a specific way.

### MachineConfig overview

The Machine Config Operator (MCO) manages updates to systemd, CRI-O and Kubelet, the kernel, Network Manager and other system features. It also offers a MachineConfig CRD that can write configuration files onto the host. Understanding what MCO does and how it interacts with other components is critical to making advanced, system-level changes to an OpenShift Container Platform cluster. Here are some things you should know about MCO, MachineConfigs, and how they are used:

- A MachineConfig can make a specific change to a file or service on the operating system of each system representing a pool of OpenShift Container Platform nodes.
- MCO is only supported for writing to files in /etc and /var directories, although there are symbolic links to some directories that can be writeable by being symbolically linked to one of those areas. The /opt directory is an example.
- Ignition is the configuration format used in MachineConfigs. See the [Ignition Configuration Specification v3.1.0](https://github.com/coreos/ignition/blob/master/docs/configuration-v3_1.md) for details.

### Checking Machine Config Pool status
To see the status of the Machine Config Operator, its sub-components, and the resources it manages, use the following oc commands:

**Procedure**
To see the number of MCO-managed nodes available on your cluster for each pool, type:

```
oc get machineconfigpool
```

result
```
NAME      CONFIG                  UPDATED  UPDATING   DEGRADED  MACHINECOUNT  READYMACHINECOUNT  UPDATEDMACHINECOUNT DEGRADEDMACHINECOUNT  AGE
master    rendered-master-dd…     True     False      False     3             3                  3                                0                     4h42m
worker    rendered-worker-fde…    True     False      False     3             3                  3                                0                     4h42m
```

In the previous output, there are three master and three worker nodes. All machines are updated and none are currently updating. Because all nodes are Updated and Ready and none are Degraded, you can ell that there are no issues.

To see each existing machineconfig, type:

```
oc get machineconfigs
```

result
```
NAME                             GENERATEDBYCONTROLLER          IGNITIONVERSION  AGE
00-master                        2c9371fbb673b97a6fe8b1c52...   3.1.0            5h18m
00-worker                        2c9371fbb673b97a6fe8b1c52...   3.1.0            5h18m
01-master-container-runtime      2c9371fbb673b97a6fe8b1c52...   3.1.0            5h18m
01-master-kubelet                2c9371fbb673b97a6fe8b1c52…     3.1.0            5h18m
...
rendered-master-dde...           2c9371fbb673b97a6fe8b1c52...   3.1.0            5h18m
rendered-worker-fde...           2c9371fbb673b97a6fe8b1c52...   3.1.0            5h18m
```
Note that the machineconfigs listed as rendered are not meant to be changed or deleted. Expect them to be hidden at some point in the future.

Check the status of worker (or change to master) to see the status of that pool of nodes:

``
oc describe mcp worker
```
...
  Degraded Machine Count:     0
  Machine Count:              3
  Observed Generation:        2
  Ready Machine Count:        3
  Unavailable Machine Count:  0
  Updated Machine Count:      3
Events:                       <none>
```

You can view the contents of a particular machineconfig (in this case, 01-master-kubelet). The trimmed output from the following oc describe command shows that this machineconfig contains both configuration files (cloud.conf and kubelet.conf) and a systemd service (Kubernetes Kubelet):

```
oc describe machineconfigs 01-master-kubelet
```

result
```
Name:         01-master-kubelet
...
Spec:
  Config:
    Ignition:
      Version:  3.1.0
    Storage:
      Files:
        Contents:
          Source:   data:,
        Mode:       420
        Overwrite:  true
        Path:       /etc/kubernetes/cloud.conf
        Contents:
          Source:   data:,kind%3A%20KubeletConfiguration%0AapiVersion%3A%20kubelet.config.k8s.io%2Fv1beta1%0Aauthentication%3A%0A%20%20x509%3A%0A%20%20%20%20clientCAFile%3A%20%2Fetc%2Fkubernetes%2Fkubelet-ca.crt%0A%20%20anonymous...
        Mode:       420
        Overwrite:  true
        Path:       /etc/kubernetes/kubelet.conf
    Systemd:
      Units:
        Contents:  [Unit]
Description=Kubernetes Kubelet
Wants=rpc-statd.service network-online.target crio.service
After=network-online.target crio.service

ExecStart=/usr/bin/hyperkube \
    kubelet \
      --config=/etc/kubernetes/kubelet.conf \ ...\
```

Using MachineConfigs to configure nodes
Tasks in this section let you create MachineConfig objects to modify files, systemd unit files, and other operating system features running on OpenShift Container Platform nodes. For more ideas on working with MachineConfigs, see content related to changing MTU network settings, adding or updating SSH authorized keys, , replacing DNS nameservers, verifying image signatures, enabling SCTP, and configuring iSCSI initiatornames for OpenShift Container Platform.

MachineConfigs

OpenShift Container Platform version 4.6 supports Ignition specification version 3.1. All new MachineConfigs you create going forward should be based on Ignition specification version 3.1. If you are upgrading your OpenShift Container Platform cluster, any existing Ignition specification version 2.x MachineConfigs will be translated automatically to specification version 3.1.

Configuring chrony time service
You can set the time server and related settings used by the chrony time service (chronyd) by modifying the contents of the chrony.conf file and passing those contents to your nodes as a machine config.

Procedure
- Create the contents of the chrony.conf file and encode it as base64. Specify any valid, reachable time source. For example:

  ```
  cat << EOF > chrony.conf
  pool 198.18.128.1 iburst
  driftfile /var/lib/chrony/drift
  rtcsync
  makestep 1.0 3
  logdir /var/log/chrony
  EOF
  ```

- Create the MachineConfig object file, replacing the base64 string with the one you just created yourself. This example adds the file to master nodes. You can change it to worker or make an additional MachineConfig object for the worker role:

  ```
  cat << EOF > ./99_masters-chrony-configuration.yaml
  apiVersion: machineconfiguration.openshift.io/v1
  kind: MachineConfig
  metadata:
    creationTimestamp: null
    labels:
      machineconfiguration.openshift.io/role: master
    name: 99-master-etc-chrony-conf
  spec:
    config:
      ignition:
        config: {}
        security:
          tls: {}
        timeouts: {}
        version: 3.1.0
      networkd: {}
      passwd: {}
      storage:
        files:
        - contents:
            source: data:text/plain;charset=utf-8;base64,$(cat chrony.conf | base64 -w 0)
          group:
            name: root
          mode: 420
          overwrite: true
          path: /etc/chrony.conf
          user:
            name: root
    osImageURL: ""
  EOF
    
  cat << EOF > ./99_workers-chrony-configuration.yaml
  apiVersion: machineconfiguration.openshift.io/v1
  kind: MachineConfig
  metadata:
    creationTimestamp: null
    labels:
      machineconfiguration.openshift.io/role: worker
    name: 99-worker-etc-chrony-conf
  spec:
    config:
      ignition:
        config: {}
        security:
          tls: {}
        timeouts: {}
        version: 3.1.0
      networkd: {}
      passwd: {}
      storage:
        files:
        - contents:
            source: data:text/plain;charset=utf-8;base64,$(cat chrony.conf | base64 -w 0)
          group:
            name: root
          mode: 420
          overwrite: true
          path: /etc/chrony.conf
          user:
            name: root
    osImageURL: ""
  EOF
  ```

- Make a backup copy of the configuration file.

- Apply the configuration in one of two ways:
  - If the cluster is not up yet, generate manifest files, add this file to the openshift directory, and then continue to create the cluster. Example:

    generate the cluster manifests:
    ```
    ./openshift-install create manifests --dir install-config/ --log-level debug
    ```

    And then copy the 2 files into install_dir/manifests:
    ```
    cp 99_masters-chrony-configuration.yaml install-config/manifests/.
    cp 99_workers-chrony-configuration.yaml install-config/manifests/.
    ```

    Then, deploy the cluster:
    ```
    ./openshift-install create cluster --dir install-config/ --log-level debug
    ```

  - If the cluster is already running, apply the file as follows:
    ```
    oc apply -f ./99_masters-chrony-configuration.yaml
    oc apply -f ./99_workers-chrony-configuration.yaml
    ```

