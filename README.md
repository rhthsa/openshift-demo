# OpenShift Demo

![](images/OpenShiftContainerPlatform.png)

## Gitbook
Check here for [Gitbook](https://rhthsa.github.io/openshift-demo/)

## Table of Contents
### Infrastructure
- [OpenShift Authentication Providers with AD](infrastructure-authentication-providers.md)
  - OpenShift External Authentication Provider
  - LDAP group sync
  - Group Policy
  - Access and Projects collaboration
- [OpenShift MachineSet and Infrastructure Nodes](infrastructure-infra-nodes.md)
  - MachineSet on VMware
  - Infrastructure Node and Moving Cluster Services to Infra Nodes
- [OpenShift Platform Monitoring and Alert](infrastructure-monitoring-alerts.md)
  - Monitoring Stack
  - AlertRules and Alert Receiver
- [OpenShift Cluster Logging](infrastructure-cluster-logging.md)
- [Loki](loki.md)
- OpenShift Networking
  - [Network Policy](network-policy.md)
- [OpenShift state backup with etcd snapshot](infrastructure-backup-etcd.md)
- [Pod Taint and Toleration](infrastructure-taint-and-toleration.md)
- [Assign pod to node](assign-pod-to-node.md)
- [Custom Roles and Service Account](custom-roles.md)
- [Custom Alert](custom-alert.md)
- [Compliance](compliance-operator.md)
- [Network Observability](netobserv.md)
### Multi-cluster Management with Advanced Cluster Management (RHACM)
- [Application Manageement](acm-application-management.md)
- [Cost saving with hibernating OpenShift](acm-hibernate.md)
### Container Applications
- Application Build & Deployment
  - [Developer Console](build-with-dev-console.md)
  - [Command Line with oc](build-with-oc.md)
  - [Command Line with odo](build-with-odo.md)
  - [Helm](helm.md) 
  - [Image Streams](imagestreams.md)
  - [OpenShift Route](openshift-route.md)
    - Blue/Green Deployment
    - Canary Deployment
    - Configure TLS version
  - [Horizontal Pod Autoscaler](hpa.md)
    - HPA by CPU
    - HPA by Memory
    - HPA by Custom Metrics
  - [Health Check](health.md)
    - Readiness Probe
    - Liveness Probe
    - Startup Probe
  - [Kustomize](kustomize.md)
  - [User Workload Monitoring](application-metrics.md)
    - Setup User Workload Monitoring
    - Monitor Custom Metrics
    - Custom Grafana Dashboard
    - Custom Alert
  - [OpenTelemetry with Tempo](otel-and-tempo.md)
  - [Build Container with OC command](build-with-oc.md)
  - [Build Container with OpenShift DO (odo)](build-with-odo.md)
  - [CI/CD with Jenkins](ci-cd-with-jenkins.md)
    - Build Quarkus App
    - Pull artifacts from Nexus
    - Unit Test
    - Code Quality
    - Push container image to Nexus or internal registry
    - Blue/Green Deployment
  - [CI/CD with Azure DevOps](ci-cd.md)
    - Azure DevOps
    - Deploy Back App
    - Deploy Front App
    - Prepare Harbor On Kubernetes/OpenShift
    - Prepare Azure DevOps Service Connection
    - Azure pipelines
  - [EAP on OpenShift](eap-on-ocp.md)
  - [gRPC or HTTP/2 Ingress Connectivity in OpenShift](grpc.md)
- Advanced Cluster Security for Kubernetes
  - [ACS](acs.md)
- Additional Solutions
  <!-- - [Managed Multi-Cluster Application Metrics with Prometheus & Thanos](thanos-receive.md) -->
  - [OpenShift GitOps](gitops.md)
  - [OpenShift Service Mesh](openshift-service-mesh.md)
      - Install and configure control plane
      - Sidecar injection
      - Blue/Green Deployment
      - Canary Deployment
      - A/B Testing Deployment
      - Routing by URI with regular expression
      - Traffic Analysis
      - Traffic Mirroring
      - Tracing
      - Circuit Breaker
      - Secure with mTLS
      - JWT Token (with RHSSO)
      - Service Level Objective (SLO)
      - Control Plane with High Availability
      - Rate Limit (OSSM 2.0.x or ISTIO 1.6)
  <!-- - [Kubernetes Event Driven Autoscaler - KEDA](KEDA.md) -->