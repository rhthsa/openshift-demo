# Clair4 on OpenShift
- [Clair4 on OpenShift](#clair4-on-openshift)
  - [Setup Clair4 on Openshift](#setup-clair4-on-openshift)
  - [Test Clair4 scan image](#test-clair4-scan-image)

## Setup Clair4 on Openshift
- new openshift project
  ```bash
  oc new-project quay-enterprise
  ```

- create clair database with postgres
  
  create [clairv4-postgres.yaml](manifests/clair4/clairv4-postgres.yaml)

  ```yaml
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: clairv4-postgres
    namespace: quay-enterprise
    labels:
      quay-component: clairv4-postgres
  spec:
    replicas: 1
    selector:
      matchLabels:
        quay-component: clairv4-postgres
    template:
      metadata:
        labels:
          quay-component: clairv4-postgres
      spec:
        volumes:
          - name: postgres-data
            persistentVolumeClaim:
              claimName: clairv4-postgres
        containers:
          - name: postgres
            image: postgres:11.5
            imagePullPolicy: "IfNotPresent"
            resources:
              limits:
                cpu: '2'
                memory: 6Gi
              requests:
                cpu: '1'
                memory: 4Gi
            ports:
              - containerPort: 5432
            env:
              - name: POSTGRES_USER
                value: "postgres"
              - name: POSTGRES_DB
                value: "clair"
              - name: POSTGRES_PASSWORD
                value: "postgres"
              - name: PGDATA
                value: "/etc/postgres/data"
            volumeMounts:
              - name: postgres-data
                mountPath: "/etc/postgres"
  ---
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: clairv4-postgres
    labels:
      quay-component: clairv4-postgres
  spec:
    accessModes:
      - "ReadWriteOnce"
    resources:
      requests:
        storage: "10Gi"
      volumeName: "clairv4-postgres"
  ```

- run create clair database with postgres
  ```bash
  oc create -f clairv4-postgres.yaml
  ```

- create config clair combo (all in one pod) [config.yaml](manifests/clair4/config.yaml)
  ```yaml
  introspection_addr: :8089
  http_listen_addr: :8080
  log_level: debug
  indexer:
    connstring: host=clairv4-postgres port=5432 dbname=clair user=postgres password=postgres sslmode=disable
    scanlock_retry: 10
    layer_scan_concurrency: 5
    migrations: true
  matcher:
    connstring: host=clairv4-postgres port=5432 dbname=clair user=postgres password=postgres sslmode=disable
    max_conn_pool: 100
    run: ""
    migrations: true
    indexer_addr: clair-indexer
  notifier:
    connstring: host=clairv4-postgres port=5432 dbname=clair user=postgres password=postgres sslmode=disable
    delivery: 1m
    poll_interval: 5m
    migrations: true
  ```
- Create a secret from the Clair config.yaml
  ```bash
  oc create secret generic clairv4-config-secret --from-file=./config.yaml
  ```
- Create the Clair v4 deployment file [clair-combo.yaml](manifests/clair4/clair-combo.yaml) 
  ```yaml
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      quay-component: clair-combo
    name: clair-combo
  spec:
    replicas: 1
    selector:
      matchLabels:
        quay-component: clair-combo
    template:
      metadata:
        labels:
          quay-component: clair-combo
      spec:
        containers:
          - image: quay.io/projectquay/clair:4.1.0
            imagePullPolicy: IfNotPresent
            name: clair-combo
            env:
              - name: CLAIR_CONF
                value: /clair/config.yaml
              - name: CLAIR_MODE
                value: combo
            ports:
              - containerPort: 8080
                name: clair-http
                protocol: TCP
              - containerPort: 8089
                name: clair-intro
                protocol: TCP
            volumeMounts:
              - mountPath: /clair/
                name: config
        imagePullSecrets:
          - name: redhat-pull-secret
        restartPolicy: Always
        volumes:
          - name: config
            secret:
              secretName: clairv4-config-secret
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: clairv4
    labels:
      quay-component: clair-combo
  spec:
    ports:
      - name: clair-http
        port: 80
        protocol: TCP
        targetPort: 8080
      - name: clair-introspection
        port: 8089
        protocol: TCP
        targetPort: 8089
    selector:
      quay-component: clair-combo
    type: ClusterIP
  ```
- expose route clair for external ocp
  ```bash
  oc expose svc/clairv4
  ```  
## Test Clair4 scan image
- install clairctl from https://quay.github.io/clair/howto/getting_started.html
- or download from https://github.com/quay/clair/releases
- example command
  ```bash
  clairctl report -host <URL> quay.io/voravitl/todo:latest
  clairctl report -host <URL> ubuntu:focal
  ```
- for private registry, required login by docker/podman befor run above command.


  
