# Infrastructure Networking

<!-- TOC -->

- [Infrastructure Networking](#infrastructure-networking)
  - [Prerequisites](#prerequisites)
  - [OpenShift Network Policy Based SDN](#openshift-network-policy-based-sdn)
    - [Switch Your Project](#switch-your-project)
    - [Execute the Creation Script](#execute-the-creation-script)
    - [Examine the created infrastructure](#examine-the-created-infrastructure)
    - [Test Connectivity (should work)](#test-connectivity-should-work)
    - [Restricting Access](#restricting-access)
    - [Test Connectivity #2 (should fail)](#test-connectivity-2-should-fail)
    - [Allow Access](#allow-access)
    - [Test Connectivity #3 (should work again)](#test-connectivity-3-should-work-again)
    - [Test Connectivity #4 while chaning NetworkPolicy](#test-connectivity-4-while-chaning-networkpolicy)
  - [Egress IP address assignment for project egress traffic](#egress-ip-address-assignment-for-project-egress-traffic)
    - [Configuring automatically assigned egress IP addresses for a namespace](#configuring-automatically-assigned-egress-ip-addresses-for-a-namespace)
  - [Network Logging](#network-logging)

<!-- /TOC -->

## Prerequisites

  - OpenShift 4.6 on VMware 6.7 U3+ or 7.0

## OpenShift Network Policy Based SDN
OpenShift has a software defined network (SDN) inside the platform that is based
on Open vSwitch. This SDN is used to provide connectivity between application
components inside of the OpenShift environment. It comes with default network
ranges pre-configured, although you can make changes to these should they
conflict with your existing infrastructure, or for whatever other reason you may
have.

The OpenShift Network Policy SDN plug-in allows projects to truly isolate their
network infrastructure inside OpenShift’s software defined network. While you
have seen projects isolate resources through OpenShift’s RBAC, the network policy
SDN plugin is able to isolate pods in projects using pod and namespace label selectors.

The network policy SDN plugin was introduced in OpenShift 3.7, and more
information about it and its configuration can be found in the
link:https://docs.openshift.com/container-platform/3.11/architecture/networking/sdn.html[networking
documentation^]. Additionally, other vendors are working with the upstream
Kubernetes community to implement their own SDN plugins, and several of these
are supported by the vendors for use with OpenShift. These plugin
implementations make use of appc/CNI, which is outside the scope of this lab.

### Switch Your Project
Before continuing, make sure you are using a project that actually exists. If
the last thing you did in the previous lab was delete a project, this will
cause errors in the scripts in this lab.

```
oc project default
```

### Execute the Creation Script
Only users with project or cluster administration privileges can manipulate *Project*
networks.

Then, execute a script that we have prepared for you. It will create two
*Projects* and then deploy a *DeploymentConfig* with a *Pod* for you:

```
oc new-project netproj-a
oc label namespace netproj-a app=iperf3-client
oc new-project netproj-b
oc label namespace netproj-b app=iperf3-server

cat <<EOF | oc create -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iperf3-server-deployment
  namespace: netproj-b
  labels:
    app: iperf3-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iperf3-server
  template:
    metadata:
      labels:
        app: iperf3-server
    spec:
      containers:
      - name: iperf3-server
        image: networkstatic/iperf3
        args: ['-s']
        ports:
          - name: server
            containerPort: 5201
            protocol: TCP
          - name: server-udp
            containerPort: 5201
            protocol: UDP
      terminationGracePeriodSeconds: 0
---
apiVersion: v1
kind: Service
metadata:
  name: iperf3-server
  namespace: netproj-b
spec:
  selector:
    app: iperf3-server
  ports:
  - protocol: TCP
    port: 5201
    targetPort: server
    name: server
  - protocol: UDP
    port: 5201
    targetPort: server-udp
    name: server-udp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iperf3-clients
  namespace: netproj-a
  labels:
    app: iperf3-client
spec:
  selector:
    matchLabels:
      app: iperf3-client
  template:
    metadata:
      labels:
        app: iperf3-client
    spec:
      containers:
      - name: iperf3-client
        image: networkstatic/iperf3
        command: ['/bin/sh', '-c', 'sleep infinity']
      terminationGracePeriodSeconds: 0
EOF
```

### Examine the created infrastructure
Two *Projects* were created for you, `netproj-a` and `netproj-b`. Execute the
following command to see the created resources:

```
oc get pods -n netproj-a
```

After a while you will see something like the following:

```
NAME                             READY   STATUS    RESTARTS   AGE
iperf3-clients-7c566cfdc-7dtn5   1/1     Running   0          14m
```

Similarly:

```
oc get pods -n netproj-b
```

After a while you will see something like the following:

```
NAME                                      READY   STATUS    RESTARTS   AGE
iperf3-server-deployment-79c44f8b-6bkrn   1/1     Running   0          14m
```

We will run commands inside the pod in the `netproj-a` *Project* that will
connect to TCP port 5201 of the pod in the `netproj-b` *Project*.

### Test Connectivity (should work)
Now that you have some projects and pods, let's test the connectivity between
the pod in the `netproj-a` *Project* and the pod in the `netproj-b` *Project*.

To test connectivity between the two pods, run:

```
export client=$(oc get pod -n netproj-a | grep iperf3-clients | cut -d' ' -f1)

oc exec $client -n netproj-a -- /bin/sh -c 'iperf3 -c iperf3-server.netproj-b.svc.cluster.local -t 10 -b 1G'
```

You will see something like the following:

```
Connecting to host iperf3-server.netproj-b.svc.cluster.local, port 5201
[  5] local 10.131.0.55 port 58320 connected to 172.30.101.62 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   119 MBytes   997 Mbits/sec    0    491 KBytes
[  5]   1.00-2.00   sec   119 MBytes  1.00 Gbits/sec    1    691 KBytes
[  5]   2.00-3.00   sec   119 MBytes  1.00 Gbits/sec    1   1.21 MBytes
[  5]   3.00-4.00   sec   119 MBytes  1.00 Gbits/sec    1   1.21 MBytes
[  5]   4.00-5.00   sec   119 MBytes   999 Mbits/sec    1   1.55 MBytes
[  5]   5.00-6.00   sec   119 MBytes  1.00 Gbits/sec    0   1.71 MBytes
[  5]   6.00-7.00   sec   119 MBytes  1.00 Gbits/sec    0   1.71 MBytes
[  5]   7.00-8.00   sec   119 MBytes   997 Mbits/sec    0   1.71 MBytes
[  5]   8.00-9.00   sec   119 MBytes  1.00 Gbits/sec    1   1.71 MBytes
[  5]   9.00-10.00  sec   119 MBytes  1.00 Gbits/sec    1   1.79 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.16 GBytes  1000 Mbits/sec    6             sender
[  5]   0.00-10.00  sec  1.16 GBytes  1000 Mbits/sec                  receiver

iperf Done.
```

Note that the last line says `worked`. This means that the pod in the
`netproj-a` *Project* was able to connect to the pod in the `netproj-b`
*Project*.

This worked because, by default, with the network policy SDN, all pods in all
projects can connect to each other.

### Restricting Access
With the Network Policy based SDN, it's possible to restrict access in a
project by creating a `NetworkPolicy` custom resource (CR).

For example, the following restricts all access to all pods in a *Project*
where this `NetworkPolicy` CR is applied. This is the equivalent of a `DenyAll`
default rule on a firewall:

```
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: deny-by-default
spec:
  podSelector:
  ingress: []
```

Note that the `podSelector` is empty, which means that this will apply to all
pods in this *Project*. Also note that the `ingress` list is empty, which
means that there are no allowed `ingress` rules defined by this
`NetworkPolicy` CR.

To restrict access to the pod in the `netproj-b` *Project* simply apply the
above NetworkPolicy CR with:

```
cat <<EOF | oc create -n netproj-b -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: deny-by-default
spec:
  podSelector:
  ingress: []
EOF
```

### Test Connectivity #2 (should fail)
Since the "block all by default" `NetworkPolicy` CR has been applied,
connectivity between the pod in the `netproj-a` *Project* and the pod in the
`netproj-b` *Project* should now be blocked.

Test by running:

```
oc exec $client -n netproj-a -- /bin/sh -c 'iperf3 -c iperf3-server.netproj-b.svc.cluster.local -t 10 -b 1G'
```

You will see something like the following:

```
iperf3: error - unable to connect to server: Connection timed out
command terminated with exit code 1
```

Note the last line that says `FAILED!`. This means that the pod in the
`netproj-a` *Project* was unable to connect to the pod in the `netproj-b`
*Project* (as expected).

### Allow Access
With the Network Policy based SDN, it's possible to allow access to
individual or groups of pods in a project by creating multiple
`NetworkPolicy` CRs.

The following allows access to port 5000 on TCP for all pods in the project
with the label `app: iperf3-server`. The pod in the `netproj-b` project has this label.

The ingress section specifically allows this access from all projects that
have the label `app: iperf3-client`.

```
# allow access to TCP port 5201 for pods with the label "run: ose" specifically
# from projects with the label "name: netproj-a".
cat <<EOF | oc create -n netproj-b -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-tcp-5201-from-netproj-a-namespace
  namespace: netproj-b
spec:
  podSelector:
    matchLabels:
      app: iperf3-server
  ingress:
  - ports:
    - protocol: TCP
      port: 5201
    from:
    - namespaceSelector:
        matchLabels:
          app: iperf3-client
EOF
```

Note that the `podSelector` is where the local project's pods are matched
using a specific label selector.

All `NetworkPolicy` CRs in a project are combined to create the allowed
ingress access for the pods in the project. In this specific case the "deny
all" policy is combined with the "allow TCP 5201" policy.

### Test Connectivity #3 (should work again)
Since the "allow access from `netproj-a` on port 5000" NetworkPolicy has been applied,
connectivity between the pod in the `netproj-a` *Project* and the pod in the
`netproj-b` *Project* should be allowed again.

Test by running:

```
oc exec $client -n netproj-a -- /bin/sh -c 'iperf3 -c iperf3-server.netproj-b.svc.cluster.local -t 10 -b 1G'
```

You will see something like the following:

```
Connecting to host iperf3-server.netproj-b.svc.cluster.local, port 5201
[  5] local 10.131.0.55 port 34702 connected to 172.30.101.62 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   119 MBytes   999 Mbits/sec    2    274 KBytes
[  5]   1.00-2.00   sec   119 MBytes  1.00 Gbits/sec    0    300 KBytes
[  5]   2.00-3.00   sec   119 MBytes  1.00 Gbits/sec    0    362 KBytes
[  5]   3.00-4.00   sec   119 MBytes  1.00 Gbits/sec    0    385 KBytes
[  5]   4.00-5.00   sec   119 MBytes   999 Mbits/sec    0    397 KBytes
[  5]   5.00-6.00   sec   119 MBytes  1.00 Gbits/sec    0    403 KBytes
[  5]   6.00-7.00   sec   119 MBytes   999 Mbits/sec    1    412 KBytes
[  5]   7.00-8.00   sec   119 MBytes  1.00 Gbits/sec    0    448 KBytes
[  5]   8.00-9.00   sec   119 MBytes  1.00 Gbits/sec    1    459 KBytes
[  5]   9.00-10.00  sec   119 MBytes   999 Mbits/sec    0    463 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.16 GBytes  1000 Mbits/sec    4             sender
[  5]   0.00-10.03  sec  1.16 GBytes   997 Mbits/sec                  receiver

iperf Done.

```

Note the last line that says `worked`. This means that the pod in the
`netproj-a` *Project* was able to connect to the pod in the `netproj-b`
*Project* (as expected).

### Test Connectivity #4 while chaning NetworkPolicy

To show NetworkPolicy is non-disruptive to the application connections while updating the network policies. We will run a test for 30 seconds and try to update network policies in between the test

Verify that UDP 5201 is still closed by running:

```
oc exec $client -n netproj-a -- /bin/sh -c 'iperf3 -c iperf3-server.netproj-b.svc.cluster.local -u -t 10 -b 1G'
```

The UDP connection should be failed

```
iperf3: error - unable to read from stream socket: Resource temporarily unavailable
Connecting to host iperf3-server.netproj-b.svc.cluster.local, port 5201
command terminated with exit code 1
```

Run the test again as TCP 5201 for 30 seconds.

```
oc exec $client -n netproj-a -- /bin/sh -c 'iperf3 -c iperf3-server.netproj-b.svc.cluster.local -t 30 -b 1G'
```

And update network policy while the test is still running eg. also add UDP port 5201 in OpenShift console

```
spec:
  podSelector:
    matchLabels:
      app: iperf3-server
  ingress:
    - ports:
        - protocol: TCP
          port: 5201
        - protocol: UDP
          port: 5201
      from:
        - namespaceSelector:
            matchLabels:
              app: iperf3-client
  policyTypes:
    - Ingress
```

TCP test result should be able to complete without connection reset or disconnect.

```
Connecting to host iperf3-server.netproj-b.svc.cluster.local, port 5201
[  5] local 10.131.0.55 port 56720 connected to 172.30.101.62 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   119 MBytes  1000 Mbits/sec    1    878 KBytes
[  5]   1.00-2.00   sec   119 MBytes  1.00 Gbits/sec    0   1.04 MBytes
[  5]   2.00-3.00   sec   119 MBytes   999 Mbits/sec    0   1.09 MBytes
[  5]   3.00-4.00   sec   119 MBytes  1.00 Gbits/sec    0   1.54 MBytes
[  5]   4.00-5.00   sec   119 MBytes  1.00 Gbits/sec    0   1.62 MBytes
[  5]   5.00-6.00   sec   119 MBytes   997 Mbits/sec    0   1.97 MBytes
[  5]   6.00-7.00   sec   118 MBytes   989 Mbits/sec    0   1.97 MBytes
[  5]   7.00-8.00   sec   121 MBytes  1.01 Gbits/sec    1   2.07 MBytes
[  5]   8.00-9.00   sec   119 MBytes   999 Mbits/sec    0   2.17 MBytes
[  5]   9.00-10.00  sec   119 MBytes  1.00 Gbits/sec    1   2.40 MBytes
[  5]  10.00-11.00  sec   119 MBytes  1.00 Gbits/sec    0   2.52 MBytes
[  5]  11.00-12.00  sec   119 MBytes   999 Mbits/sec    1   2.52 MBytes
[  5]  12.00-13.00  sec   119 MBytes  1000 Mbits/sec    1   2.52 MBytes
[  5]  13.00-14.00  sec   119 MBytes  1.00 Gbits/sec    1   2.52 MBytes
[  5]  14.00-15.00  sec   119 MBytes   999 Mbits/sec    0   2.52 MBytes
[  5]  15.00-16.00  sec   119 MBytes  1.00 Gbits/sec    0   2.52 MBytes
[  5]  16.00-17.00  sec   119 MBytes  1.00 Gbits/sec    0   2.52 MBytes
[  5]  17.00-18.00  sec   119 MBytes   999 Mbits/sec    0   2.64 MBytes
[  5]  18.00-19.00  sec   119 MBytes  1.00 Gbits/sec    0   2.64 MBytes
[  5]  19.00-20.00  sec   119 MBytes  1.00 Gbits/sec    0   2.77 MBytes
[  5]  20.00-21.00  sec   119 MBytes   999 Mbits/sec    0   2.77 MBytes
[  5]  21.00-22.00  sec   119 MBytes  1.00 Gbits/sec    0   2.77 MBytes
[  5]  22.00-23.00  sec   119 MBytes  1.00 Gbits/sec    0   2.77 MBytes
[  5]  23.00-24.00  sec   119 MBytes   997 Mbits/sec    0   2.77 MBytes
[  5]  24.00-25.01  sec   119 MBytes   988 Mbits/sec    0   2.77 MBytes
[  5]  25.01-26.00  sec   120 MBytes  1.02 Gbits/sec    0   2.77 MBytes
[  5]  26.00-27.00  sec   119 MBytes   999 Mbits/sec    1   2.77 MBytes
[  5]  27.00-28.00  sec   119 MBytes  1.00 Gbits/sec    1   2.77 MBytes
[  5]  28.00-29.01  sec   119 MBytes   985 Mbits/sec    0   2.77 MBytes
[  5]  29.01-30.00  sec   120 MBytes  1.01 Gbits/sec    1   2.77 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-30.00  sec  3.49 GBytes  1000 Mbits/sec    9             sender
[  5]   0.00-30.02  sec  3.49 GBytes   999 Mbits/sec                  receiver

iperf Done.
```

Re-run UDP test again to confirm UDP 5201 has been allowed.

```
oc exec $client -n netproj-a -- /bin/sh -c 'iperf3 -c iperf3-server.netproj-b.svc.cluster.local -u -t 10 -b 1G'
```

iperf3 UDP test is now working

```
Connecting to host iperf3-server.netproj-b.svc.cluster.local, port 5201
[  5] local 10.131.0.55 port 39507 connected to 172.30.4.76 port 5201
[ ID] Interval           Transfer     Bitrate         Total Datagrams
[  5]   0.00-1.00   sec  26.0 MBytes   218 Mbits/sec  19520
[  5]   1.00-2.00   sec  30.2 MBytes   253 Mbits/sec  22663
[  5]   2.00-3.00   sec  33.4 MBytes   279 Mbits/sec  25072
[  5]   3.00-4.00   sec  30.0 MBytes   253 Mbits/sec  22486
[  5]   4.00-5.00   sec  34.6 MBytes   291 Mbits/sec  25986
[  5]   5.00-6.00   sec  35.3 MBytes   296 Mbits/sec  26455
[  5]   6.00-7.00   sec  35.7 MBytes   299 Mbits/sec  26766
[  5]   7.00-8.00   sec  33.6 MBytes   281 Mbits/sec  25183
[  5]   8.00-9.00   sec  37.6 MBytes   317 Mbits/sec  28229
[  5]   9.00-10.00  sec  36.7 MBytes   308 Mbits/sec  27537
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Jitter    Lost/Total Datagrams
[  5]   0.00-10.00  sec   333 MBytes   279 Mbits/sec  0.000 ms  0/249897 (0%)  sender
[  5]   0.00-10.01  sec   286 MBytes   240 Mbits/sec  0.025 ms  35426/249897 (14%)  receiver

iperf Done.
```

## Egress IP address assignment for project egress traffic

As a cluster administrator, you can configure the OpenShift SDN default Container Network Interface (CNI) network provider to assign one or more egress IP addresses to a project.

By configuring an egress IP address for a project, all outgoing external connections from the specified project will share the same, fixed source IP address. External resources can recognize traffic from a particular project based on the egress IP address. An egress IP address assigned to a project is different from the egress router, which is used to send traffic to specific destinations.

Egress IP addresses are implemented as additional IP addresses on the primary network interface of the node and must be in the same subnet as the node’s primary IP address.

High availability of nodes is automatic. If a node that hosts an egress IP address is unreachable and there are nodes that are able to host that egress IP address, then the egress IP address will move to a new node. When the unreachable node comes back online, the egress IP address automatically moves to balance egress IP addresses across nodes.

### Configuring automatically assigned egress IP addresses for a namespace

In OpenShift Container Platform you can enable automatic assignment of an egress IP address for a specific namespace across one or more nodes.

1. Test ping from pod in netproj-a to VM outside OpenShift, the source IP Address is the Node IP Address
    ```
    [root@centos7-tools1 ~]# tcpdump -i ens160 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on ens160, link-type EN10MB (Ethernet), capture size 262144 bytes
    08:37:18.756559 IP 198.18.1.18 > tools1.dcloud.cisco.com: ICMP echo request, id 3, seq 1, length 64
    08:37:18.756627 IP tools1.dcloud.cisco.com > 198.18.1.18: ICMP echo reply, id 3, seq 1, length 64
    08:37:19.757960 IP 198.18.1.18 > tools1.dcloud.cisco.com: ICMP echo request, id 3, seq 2, length 64
    08:37:19.758014 IP tools1.dcloud.cisco.com > 198.18.1.18: ICMP echo reply, id 3, seq 2, length 64
    ```
2. Update the NetNamespace object with the egress IP address using the following JSON:
    ```
    oc patch netnamespace netproj-a --type=merge -p \
    '{"egressIPs": ["198.18.1.241"]}'
    ```
    You can set egressIPs to two or more IP addresses on different nodes to provide high availability. If multiple egress IP addresses are set, pods use the first IP in the list for egress, but if the node hosting that IP address fails, pods switch to using the next IP in the list after a short delay.
3. Manually assign the egress IP to the node hosts. Set the egressIPs parameter on the HostSubnet object on the node host. Using the following JSON, include as many IPs as you want to assign to that node host:
    
    ```
    for node in $(oc get nodes | grep '\-worker' | cut -d' ' -f1); do
    oc patch hostsubnet $node --type=merge -p '{"egressCIDRs": ["198.18.1.0/24"]}'
    done
    ```
    
    In the previous example, all egress traffic for project1 will be routed to the node hosting the specified egress IP, and then connected (using NAT) to that IP address.
4. Test ping from the same POD in netproj-a again, now the source IP Address is now egressIP assigned to netproj-a
    ```
    [root@centos7-tools1 ~]# tcpdump -i ens160 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on ens160, link-type EN10MB (Ethernet), capture size 262144 bytes
    09:08:33.841050 IP 198.18.1.241 > registry0.example.com: ICMP echo request, id 7, seq 130, length 64
    09:08:33.841131 IP registry0.example.com > 198.18.1.241: ICMP echo reply, id 7, seq 130, length 64
    09:08:34.861757 IP 198.18.1.241 > registry0.example.com: ICMP echo request, id 7, seq 131, length 64
    09:08:34.861815 IP registry0.example.com > 198.18.1.241: ICMP echo reply, id 7, seq 131, length 64
    ```


## Network Logging

The network access logging will be done with envoy sidecar proxy, the details will be in OpenShift Service Mesh section.

