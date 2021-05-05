# Taint and Toleration
- [Taint and Toleration](#taint-and-toleration)
  - [Pod Eviction](#pod-eviction)
    - [Node Unreachable](#node-unreachable)
## Pod Eviction

Pod eviction from node behavior can be configured by adding toleration to pod. This default value is 5 minutes in case of node unreachable or not-ready
### Node Unreachable

Configure pod to evict from node in case node is unreachable.
- Check pod default toleration
  - Check toleration 
    
    ```bash
    oc describe pod $(oc get pods | grep Running | tail -n 1 | awk '{print $1}') | \
    grep -A2 -i toleration
    ```

  - Output example. 
    - node.kubernetes.io/not-ready is 300s (5 minutes)
    - node.kubernetes.io/unreachable is 300s (5 minutes)
  
    ```bash
    Tolerations:     node.kubernetes.io/memory-pressure:NoSchedule op=Exists
                     node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                     node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
    ```

- Set unreachable to 1 minute by adding toleration for node unreachable to deployment or deployment config. This toleration mean that Pods remain bound to nodes for 60s after *unreachable* of these problems is detected.
  
  **Remark: Default value of 5 minutes is reasonable in the assumption for preventing false posivites**

  - Example of [deployment](manifests/backend.yaml) with  *unreachable* toleration set to 1 minute.
  
    ```yaml
    template:
    metadata:
        labels:
        app: backend-native
        deploymentconfig: backend-native
    spec:
        containers:
        - image: image-registry.openshift-image-registry.svc:5000/demo/backend-native@sha256:5b76fdf7113c0db6d7fddea54997dd648a55b2a04383effb82f55cdbb0419dd5
        ...
        ...
        tolerations:
        - key: node.kubernetes.io/unreachable
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 60
    ```

- Check pod toleration node.kubernetes.io/unreachable is chaged to 60s. Pod will be recreate on another node if node is unreachable for 60s
  
  ```bash
  Tolerations:     node.kubernetes.io/memory-pressure:NoSchedule op=Exists
                   node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                   node.kubernetes.io/unreachable:NoExecute op=Exists for 60s
  ```

