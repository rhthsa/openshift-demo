# Image Stream
- [Image Stream](#image-stream)
  - [Automatic trigger deployment](#automatic-trigger-deployment)

Image stream is an abstraction to container image in image registry. Image stream itself does not container any image it just a referece to actual image.

You can configure builds and deployments to watch an image stream for notifications when new images are added and react by performing a build or deployment, respectively.

## Automatic trigger deployment
- import image with schedule update ( Default is every 15 minutes)

  ```bash
  oc import-image backend  --scheduled --confirm --all --from quay.io/voravitl/backend
  oc get istag
  ```

- Setup image lookup for backend imagestream

  ```bash
  oc set image-lookup backend
  oc set image-lookup --list
  ```

- With image lookup is enabled. Imagestream name can be used in deployment

  ```yaml
      spec:
        containers:
        - name: backend
          image: backend:v1
  ```
- Check for latest update interval imagestream
  
  ```bash
  oc get istag backend:v1
  ```

  Output
  
  ```bash
  NAME         IMAGE REFERENCE                                                                                    UPDATED
  backend:v1   quay.io/voravitl/backend@sha256:19ef0afb88a1ce5d6a4422c7ab8395eb05b672fc27d5d387d9fcd8e15a44c5d7   30 seconds ago
  ```

- Deploy application
  
  ```bash
  oc apply -f backend.yaml
  ```

- Set trigger
  
  ```bash
  oc set triggers deployment/backend --from-image backend:v1 -c backend
  ```

  Trigger will set following annotation to deployment for container name backend

  ```yaml
  metadata:
    name: backend
    annotations:
      image.openshift.io/triggers: '[{"from":{"kind":"ImageStreamTag","name":"backend:v1"},"fieldPath":"spec.template.spec.containers[?(@.name==\"backend\")].image"}]'
  ```

- When image on image registry 

![](deployment-trigger.png)
