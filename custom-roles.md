# Custom Roles and Service Account
- [Custom Roles and Service Account](#custom-roles-and-service-account)
  - [Service Account](#service-account)
    - [Create Service Account](#create-service-account)
  - [Custom Roles](#custom-roles)
    - [Local Role](#local-role)
    - [Create cluster role](#create-cluster-role)
  - [Test Service Account](#test-service-account)
    - [CLI](#cli)
    - [REST API](#rest-api)
  - [Use Service Account with Deployment](#use-service-account-with-deployment)

## Service Account

Create custom roles for service account to view,list and watch 
    - configmaps
    - pods
    - services
    - namespaces
    - endpoints
    - secrets
    - *nodes*

Remark: *nodes* need cluster role

### Create Service Account
- Create Service Account
  
    ```bash
    oc create sa sa-discovery -n demo
    ```
    
    Output
    
    ```bash
    serviceaccount/sa-discovery created
    ```

## Custom Roles
### Local Role
- Create role for service account. 
   
    ```bash
    oc create role app-discovery \
    --verb=get,list,watch \
    --resource=configmaps,pods,services,namespaces,endpoints \
    -n demo
    oc describe role app-discovery -n demo
    ```

    or create from [app-discovery](manifests/app-discovery-role.yaml) yaml

    ```bash
    oc create -f manifests/app-discovery-role.yaml -n demo
    oc describe role app-discovery -n demo
    oc describe role list-secret -n demo
    ```
    
    Output
    
    ```bash
    role.rbac.authorization.k8s.io/app-discovery created
    Name:         app-discovery
    Labels:       <none>
    Annotations:  <none>
    PolicyRule:
    Resources   Non-Resource URLs  Resource Names  Verbs
    ---------   -----------------  --------------  -----
    configmaps  []                 []              [get list watch]
    endpoints   []                 []              [get list watch]
    namespaces  []                 []              [get list watch]
    pods        []                 []              [get list watch]
    secrets     []                 []              [get list watch]
    services    []                 []              [get list watch]
    ```

- Assign role to service account
    
    ```bash
    oc adm policy add-role-to-user app-discovery \
    system:serviceaccount:demo:sa-discovery --role-namespace=demo -n demo
    ```

    Output

    ```bash
    role.rbac.authorization.k8s.io/app-discovery added: "system:serviceaccount:demo:sa-discovery"   
    ```

### Create cluster role
- Create cluster role to view node
 
    ```bash
    oc create clusterrole view-nodes \
    --verb=get,list,watch --resource=nodes
    ```

    or create from [view-nodes](manifests/clusterrole-view-nodes.yaml) yaml

    ```bash
    oc create -f manifests/clusterrole-view-nodes.yaml
    ```

    Output

    ```bash
    clusterrole.rbac.authorization.k8s.io/view-nodes created
    ```

- Assign role to service account

    ```bash
    oc adm policy add-cluster-role-to-user \
    view-nodes system:serviceaccount:demo:sa-discovery 
    ```
    Output

    ```bash
    clusterrole.rbac.authorization.k8s.io/view-nodes added: "system:serviceaccount:demo:sa-discovery"
    ```

## Test Service Account
### CLI
- Test service account *sa-discovery* with CLI tool
    - Get service account *sa-discovery* token 
    
    ```bash
    TOKEN=$(oc sa get-token sa-discovery -n demo)
    ```
    
    - Login with service account token
    
    ```bash
    oc login --token=$TOKEN
    oc whoami
    ```

    Output

    ```bash
    Using project "demo".
    system:serviceaccount:demo:app-discovery
    ```
    
    -  Test list resources
    
    ```bash
    clear
    printf "List configmaps\n"
    oc get configmaps -n demo
    echo "Press any keys to continue...";read
    clear
    printf "List secrets\n"
    oc get secrets -n demo
    echo "Press any keys to continue...";read
    clear
    printf "List pods\n"
    oc get pods -n demo
    echo "Press any keys to continue...";read
    clear
    printf "List services\n"
    oc get svc -n demo
    echo "Press any keys to continue...";read
    clear
    printf "List nodes\n"
    oc get nodes
    echo "Press any keys to continue...";read
    clear
    ```

    - Test get secret
    
    ```bash
    oc describe secrets/$(oc get secrets --no-headers|head -n 1|awk '{print $1}')
    ```
    
    You will get following error because sa-discovery has only list action
    
    ```bash
    Error from server (Forbidden): secrets "builder-dockercfg-cjfz6" is forbidden: User "system:serviceaccount:demo:sa-discovery" cannot get resource "secrets" in API group "" in the namespace "demo"
    ```
### REST API
- List pods
    
    ```bash
    API=$(oc whoami --show-server)
    NAMESPACE=demo
    curl -k -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" $API/api/v1/namespaces/$NAMESPACE/pods
    ```
    
    Output

    ```json
    "items": [
        {
        "metadata": {
            "name": "backend-797f8bfdcc-xrzkw",
            "generateName": "backend-797f8bfdcc-",
            "namespace": "demo",
            "selfLink": "/api/v1/namespaces/demo/pods/backend-797f8bfdcc-xrzkw",
            "uid": "e6845671-6e46-4b20-aa7b-ced5839341e2",
            "resourceVersion": "56509",
            "creationTimestamp": "2021-06-10T09:10:10Z",
            "labels": {
            "app": "backend",
            "pod-template-hash": "797f8bfdcc",
            "version": "v1"
            },

    ```
- Get sepcified pod

    ```
    curl -k -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" $API/api/v1/namespaces/$NAMESPACE/pods/<pod-name>
    ```

- Get node

    ```bash
    curl -k -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" $API/api/v1/nodes/$(oc get nodes --no-headers|head -n 1|awk '{print $1}')
    ```

## Use Service Account with Deployment
- Backend deployment ([backend-discovery-sa.yaml](manifests/backend-discovery-sa.yaml)) with custom service account
    
    ```bash
    spec:
    replicas: 1
    selector:
        matchLabels:
        app: backend
        version: v1
    template:
        metadata:
        creationTimestamp: null
        labels:
            app: backend
            version: v1
        annotations:
            sidecar.istio.io/inject: "false"
        spec:
        serviceAccountName: svip-ignite-discovery
        automountServiceAccountToken: false
        containers:
        - name: backend
    ```

- Check service account used by pod
    
    ```bash
    oc get pod/<pod-name> -o jsonpath='{.spec.serviceAccountName}'
    ```