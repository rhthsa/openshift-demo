# Build Container Image with OpenShift DO

```
   ___                   ____  _     _  __ _     ____   ___  
  / _ \ _ __   ___ _ __ / ___|| |__ (_)/ _| |_  |  _ \ / _ \ 
 | | | | '_ \ / _ \ '_ \\___ \| '_ \| | |_| __| | | | | | | |
 | |_| | |_) |  __/ | | |___) | | | | |  _| |_  | |_| | |_| |
  \___/| .__/ \___|_| |_|____/|_| |_|_|_|  \__| |____/ \___/ 
       |_|                                                   
                                              
```
- [Build Container Image with OpenShift DO](#build-container-image-with-openshift-do)
  - [ODO Catalog](#odo-catalog)
  - [Sample Java](#sample-java)

## ODO Catalog
- list odo catalog
  
  ```bash
  odo catalog list components
  ```
  Catalog

  ```bash
  Odo Devfile Components:
  NAME                          DESCRIPTION                                                         REGISTRY
  java-maven                    Upstream Maven and OpenJDK 11                                       DefaultDevfileRegistry
  java-openliberty              Open Liberty microservice in Java                                   DefaultDevfileRegistry
  java-quarkus                  Upstream Quarkus with Java+GraalVM                                  DefaultDevfileRegistry
  java-springboot               Spring Boot® using Java                                             DefaultDevfileRegistry
  java-vertx                    Upstream Vert.x using Java                                          DefaultDevfileRegistry
  java-wildfly                  Upstream WildFly                                                    DefaultDevfileRegistry
  java-wildfly-bootable-jar     Java stack with WildFly in bootable Jar mode, OpenJDK 11 and...     DefaultDevfileRegistry
  nodejs                        Stack with NodeJS 12                                                DefaultDevfileRegistry
  python                        Python Stack with Python 3.7                                        DefaultDevfileRegistry
  python-django                 Python3.7 with Django                                               DefaultDevfileRegistry
  
  Odo S2I Components:
  NAME       PROJECT       TAGS                                                             SUPPORTED
  java       openshift     latest,openjdk-11-el7,openjdk-11-ubi8,openjdk-8-el7              YES
  nodejs     openshift     12-ubi8,14-ubi8,latest                                           YES
  dotnet     openshift     2.1-el7,2.1-ubi8,3.1-el7,3.1-ubi8                                NO
  golang     openshift     1.13.4-ubi7,1.14.7-ubi8,latest                                   NO
  httpd      openshift     2.4-el7,2.4-el8,latest                                           NO
  java       openshift     openjdk-8-ubi8                                                   NO
  nginx      openshift     1.14-el8,1.16-el7,1.16-el8,1.18-ubi7,1.18-ubi8,latest            NO
  nodejs     openshift     10-ubi7,10-ubi8,12-ubi7,14-ubi7                                  NO
  perl       openshift     5.26-el7,5.26-ubi8,5.30-el7,5.30-ubi8,latest                     NO
  php        openshift     7.2-ubi8,7.3-ubi7,7.3-ubi8,7.4-ubi8,latest                       NO
  python     openshift     2.7-ubi7,2.7-ubi8,3.6-ubi8,3.8-ubi7,3.8-ubi8,latest              NO
  ruby       openshift     2.5-ubi7,2.5-ubi8,2.6-ubi7,2.6-ubi8,2.7-ubi7,2.7-ubi8,latest     NO
  ```
## Sample Java
- Create project
  
  ```bash
  odo project create odo-demo
  ```

- Create Application
  
  - From binary
  
    ```bash
    git clone https://gitlab.com/ocp-demo/backend_quarkus && cd backend_quarkus
    cd code
    mvn clean package -DskipTests=true -Dquarkus.package.uber-jar=true
    odo create java backend --s2i --binary target/*.jar
    ```
    
    Sample output
    
    ```bash
    Validation
    ✓  Validating component [75ms]

    Please use `odo push` command to create the component with source deployed
    ```

  - From source code

    ```bash
    odo create nodejs frontend --s2i --git https://gitlab.com/ocp-demo/frontend-js 
    ```
    
    Check for odo configuration

    ```yaml
    kind: LocalConfig
    apiversion: odo.dev/v1alpha1
    ComponentSettings:
    Type: nodejs
    SourceLocation: https://gitlab.com/ocp-demo/frontend-js
    SourceType: git
    Ports:
    - 8080/TCP
    Application: app
    Project: demo
    Name: frontend
    ```

- Deploy
  
  ```bash
  odo push
  ```

  Sample outout

  ```bash
   Validation
   ✓  Checking component [125ms]

   Configuration changes
   ✓  Initializing component
   ✓  Creating component [458ms]

   Applying URL changes
   ✓  URLs are synced with the cluster, no changes are required.

   Pushing to component backend of type binary
   ✓  Checking files for pushing [19ms]
   ✓  Waiting for component to start [2m]
   ✓  Syncing files to the component [2s]
   ✓  Building component [2s]
  ```
- Expose service ( create route)
  
  ```bash
  odo url create --port 8080
  ```
  Sample outout

  ```bash
  ✓  URL backend-8080 created for component: backend

  To apply the URL configuration changes, please use `odo push`
  ```
  
  Remark: you need to run *odo push* to propagate change to OpenShift

  ```bash
    ✓  Checking component [150ms]

    Configuration changes
    ✓  Retrieving component data [213ms]
    ✓  Applying configuration [184ms]

    Applying URL changes
    ✓  URL backend-8080: http://backend-8080-app-backend-quarkus.apps.cluster-69f4.69f4.sandbox957.opentlc.com/ created

    Pushing to component backend of type binary
    ✓  Checking file changes for pushing [10ms]
    ✓  Waiting for component to start [41ms]
    ✓  Syncing files to the component [2s]
    ✓  Building component [3s]
  ```
