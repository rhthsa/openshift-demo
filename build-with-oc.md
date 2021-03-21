# Build Container Image with OC CLI

```
  ______     ______      ______  __       __  
 /  __  \   /      |    /      ||  |     |  | 
|  |  |  | |  ,----'   |  ,----'|  |     |  | 
|  |  |  | |  |        |  |     |  |     |  | 
|  `--'  | |  `----.   |  `----.|  `----.|  | 
 \______/   \______|    \______||_______||__| 
                                              
```

- [Build Container Image with OC CLI](#build-container-image-with-oc-cli)
  - [Configure OpenShift with external registry (optional)](#configure-openshift-with-external-registry-optional)
  - [Source build](#source-build)
  - [Binary build with Dockerfile](#binary-build-with-dockerfile)

## Configure OpenShift with external registry (optional)

- Create docker secret to access external registry
  
  - With user and password
  
  ```bash
  NEXUS_REGISTRY=external_registry.example.com
  oc create secret docker-registry nexus-registry --docker-server=$NEXUS_REGISTRY \
  --docker-username=$CICD_NEXUS_USER \
  --docker-password=$CICD_NEXUS_PASSWORD \
  --docker-email=unused \
  ```
  
  - From dockersecert

  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: nexus-registry
  type: kubernetes.io/dockercfg
  data:
    .dockercfg: |
          "<base64 encoded ~/.dockercfg file>"
  ```

- Link secret for builder
  
  ```bash
  oc secrets link default nexus-registry --for=pull
  ```

- Link secret for pull image
  
  ```bash
  oc secrets link builder nexus-registry
  ```

- For insecure registry 
  
  - Edit image.config.openshift.io/cluster
  
  ```bash
   oc edit image.config.openshift.io/cluster
  ```

  - Add insecure registry to spec
  
  ```yaml
  spec:
    registrySources:
      insecureRegistries:
      - nexus-registry.ci-cd.svc.cluster.local
      - nexus-registry.example.com
  ```

## Source build

*WIP*


## Binary build with Dockerfile

- Clone sample [Backend Quarkus](https://gitlab.com/ocp-demo/backend_quarkus)
  
  ```bash
  git clone https://gitlab.com/ocp-demo/backend_quarkus
  ```

- Create application binary
  
  ```bash
  cd code
  mvn clean package -DskipTests=true
  ```

- Create Build Config
  
  - Push to OpenShift's internal image registry
  
    ```bash
    APP_NAME=backend
    oc new-build --binary --name=$APP_NAME -l app=$APP_NAME
    ```

  - Push to OpenShift's external image registry
    
    ```bash
    APP_NAME=backend
    EXTERNAL_REGISTRY=nexus-registry.example.com
    EXTERNAL_REGISTRY_SECRET=nexus-registry
    TAG=latest
    oc new-build --binary --to-docker=true \
    --to=$EXTERNAL_REGISTRY/$APP_NAME:$TAG \
    --push-secret=$EXTERNAL_REGISTRY_SECRET \
    --name=$APP_NAME \
    -l app=$APP_NAME
    ```

- Change build strategy to DockerStrategy

  ```bash
  oc patch bc/$APP_NAME \
  -p "{\"spec\":{\"strategy\":{\"dockerStrategy\":{\"dockerfilePath\":\"src/main/docker/Dockerfile.jvm\"}}}}"
  ```

- Build container image
  
  ```bash
  oc start-build $APP_NAME --from-dir=. --follow
  ```

- Create Application

  - from internal image registry

    ```bash
    oc new-app --image-stream=${APP_NAME} \
    --labels=app.openshift.io/runtime=quarkus,app.openshift.io/runtime-version=11,app.kubernetes.io/part-of=Demo
    ```

- Pause rollout deployment

  ```bash
  oc expose svc $APP_NAME
  ```

- Create liveness and readiness probe

  ```bash
  oc set probe deployment/$APP_NAME --readiness \
  --get-url=http://:8080/q/health/ready \
  --initial-delay-seconds=8 \
  --failure-threshold=1 --period-seconds=10
  oc set probe deployment/$APP_NAME --liveness \
  --get-url=http://:8080/q/health/live \
  --initial-delay-seconds=5 -\
  -failure-threshold=3 --period-seconds=10
  ```

- Set request and limit

  ```bash
  oc set resources deployment $APP_NAME  --requests="cpu=50m,memory=100Mi"
  oc set resources deployment $APP_NAME  --limits="cpu=150m,memory=150Mi" 
  ```

- Create configmap

  ```bash
  oc create configmap $APP_NAME --from-file=config/application.properties
  oc set volume deployment/{APP_NAME --add --name=$APP_NAME-config \
  --mount-path=/deployments/config/application.properties \
  --sub-path=application.properties \
  --configmap-name=$APP_NAME
  ```

- Set HPA

  ```bash
  oc autoscale deployment $APP_NAME --min 2 --max 4 --cpu-percent=60
  ```

- Resume rollout deployment

  ```bash
  oc rollout resume deployment $APP_NAME
  ```

- Create route
  - Expose service
    ```bash
    oc expose svc $APP_NAME
    ```
  - Create route with edge TLS
    ```bash
    oc create route edge $APP_NAME --service=$APP_NAME --port=8080
    ```
