# Developer Console
- [Developer Console](#developer-console)
  - [Upload Uber JAR](#upload-uber-jar)
## Upload Uber JAR
- Select upload JAR
  
  ![Uber JAR](images/build-dev-console-uber-jar-01.png)

- Upload your Uber JAR and select Builder Image
  
  ![Upload JAR](images/build-dev-console-uber-jar-02.png)

- Name your application and select parameters e.g. Ingress (Route), request/limit

  ![Parameters](images/build-dev-console-uber-jar-03.png)

- View build logs

  ![view build log](images/build-dev-console-uber-jar-04.png)

  Build log

  ![build log](images/build-dev-console-uber-jar-05.png) 

- Check for build config by select menu Builds->backend->YAML
  - Base image is from *sourceStrategy*
  - Source type is *binary*

  ```yaml
  strategy:
    type: Source
    sourceStrategy:
      from:
        kind: ImageStreamTag
        namespace: openshift
        name: 'java:openjdk-11-ubi8'
  postCommit: {}
  source:
    type: Binary
    binary: {}
  ```

- Check your deployed application

  ![Uber JAR app deployed](images/build-dev-console-uber-jar-06.png) 