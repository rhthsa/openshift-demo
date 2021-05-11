# ACS
- [ACS](#acs)
  - [Installation](#installation)
    - [CLI](#cli)
    - [Configure helm repo](#configure-helm-repo)
    - [Central](#central)
    - [Secured Cluster Services](#secured-cluster-services)
    - [Test](#test)

## Installation
### CLI

- Install roxctl CLI on OSX

  ```bash
  curl -O https://mirror.openshift.com/pub/rhacs/assets/3.0.59.1/bin/Darwin/roxctl
  ```
### Configure helm repo
- Set helm repo

    ```bash
    helm repo add rhacs https://mirror.openshift.com/pub/rhacs/charts/
    helm search repo -l rhacs/
    helm repo update
    ```
### Central

- Install on OpenShift

    ```bash
    helm install -n stackrox --create-namespace \
    stackrox-central-services rhacs/central-services \
    --set imagePullSecrets.allowNone=true \
    --set central.exposure.route.enabled=true
    ```

    Install with cert
    
    ```bash
    helm install -n stackrox --create-namespace \
    stackrox-central-services rhacs/central-services \
    --set imagePullSecrets.allowNone=true \
    --set central.exposure.route.enabled=true \
    --set-file central.defaultTLS.cert=/path/to/tls-cert.pem \
    --set-file central.defaultTLS.key=/path/to/tls-key.pem
    ```

- Save user/password
  
    ```bash
    StackRox 3.0.59.1 has been installed.

    An administrator password has been generated automatically. Use username 'admin' and the following
    password to log in for initial setup:

    Ixd3*********************Pw***
    ```
- Check for Central's route
  
    ```bash
    echo "https://$(oc get route central -n stackrox -o jsonpath='{.spec.host}')"
    ```

### Secured Cluster Services
- Create *authentication token*
- Login to Central
- Platform Configuration -> Integrations -> Authentication Tokens Select StackRox API Token then generate token and copy token to clipboard
  - Token Name: admin
  - Role: Admin
- Set environment variable
    
    ```bash
    export ROX_API_TOKEN=<api-token>
    export ROX_CENTRAL_ADDRESS=https://$(oc get route central -n stackrox -o jsonpath='{.spec.host}'):443
    ```

- Generate cluster init bundle
  
    ```bash
    CLUSTER_NAME=acs-demo
    roxctl --insecure-skip-tls-verify -e "$ROX_CENTRAL_ADDRESS" central init-bundles generate $CLUSTER_NAME \
    --output $CLUSTER_NAME-init-bundle.yaml
    ```

- Install Secure Cluster Services
    - on Local cluster
    
    ```bash
    helm install -n stackrox --create-namespace stackrox-secured-cluster-services rhacs/secured-cluster-services \
    -f ${CLUSTER_NAME}-init-bundle.yaml \
    --set clusterName=${CLUSTER_NAME} \
    --set imagePullSecrets.allowNone=true
    ```
    
    - on Remote cluster
    
    ```bash
    helm install -n stackrox --create-namespace stackrox-secured-cluster-services rhacs/secured-cluster-services \
    -f ${CLUSTER_NAME}-init-bundle.yaml \
    --set centralEndpoint=${ROX_CENTRAL_ADDRESS} \
    --set clusterName=${CLUSTER_NAME} \
    --set imagePullSecrets.allowNone=true
    ```

### Test
- Deploy sample application

    ```bash
    oc new-project test
    oc run sample-vul --labels=app=backend --image=quay.io/voravitl/backend:vul -n test 
    watch oc get pods -n test
    ```
- Check ACS console
  
  ![](images/acs-backend-vul.png)