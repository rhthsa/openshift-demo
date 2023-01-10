# Custom Monitoring

- [Custom Monitoring](#custom-monitoring)
  - [Monitor Pod Creation](#monitor-pod-creation)
  - [Monitor Project Quotas](#monitor-project-quotas)
    - [Cluster Level](#cluster-level)
  - [Test Alert](#test-alert)
    - [CrashLoopBackOff and ImagePullBackOff](#crashloopbackoff-and-imagepullbackoff)
    - [OOMKilled](#oomkilled)
  - [Alert with LINE](#alert-with-line)
    - [LINE BOT Configuration](#line-bot-configuration)

## Monitor Pod Creation
  - Create custom alerts to monitor for pod creating status with PrometheusRule [pod-stuck-alerts.yaml](manifests/pod-stuck-alerts.yaml)
   
  - This *PrometheusRule* will sending alerts if pod status 
    - PodStuckContainerCreating for 2 minutes
    - PodStuckImagePullBackOff for 30 seconds
    - PodStuckErrImagePull for 2 minuts
    - PodStuckCrashLoopBackOff for 2 minutes
    - PodStuckCreateContainerError for 2 minutes
    - OOMKilled for 3 minutes

## Monitor Project Quotas
  - Create custom alerts to monitor for project quotas  with PrometheusRule [quota-alert.yaml](manifests/quota-alert.yaml)
   
  - This *PrometheusRule* will sending alerts if
    - Project used CPU/memory request/limits more than 90% will alert with critical severity
    - Project used CPU/memory request/limits more than 80% and less than 90% with warning severity

    
### Cluster Level
  - Create *[PrometheusRule](manifests/pod-stuck-alerts.yaml)* in namespace *openshift-monitoring*
  
  ```bash
  oc create -f manifests/pod-stuck-alerts.yaml
  oc create -f manifests/quota-alert.yaml
  ```

  - Check alerting rules

    ![](images/monitoring-alert.png)
  
  - View alerting rules *cpuRequestQuotaCritical*

    ![](images/cpuRequestQuotaCriticalAlert.png)

<!-- ### User Workload Monitoring
  - If [user workload monitoring](application-metrics.md) is enabled. Prometheus Rule can be created at project level.
    
    ```bash
    oc create -f manifests/pod-stuck-alerts.yaml -n demo
    ```

  - Add following label to deploy rules to Thanos Ruler
  
    ```yaml
    metadata:
      name: pod-stuck
      labels:
       openshift.io/prometheus-rule-evaluation-scope: leaf-prometheus
    ```

  - Check for alert rules in Developer Console

      ![](images/monitoring-alert-user-workload.png) -->

## Test Alert

### CrashLoopBackOff and ImagePullBackOff

  - Create following [pod-stuck](manifests/pod-stuck.yaml) deployments. These deployments intentionally put pods into error state.
  
  ```bash
  oc create -f manifests/pod-stuck.yaml -n demo
  ```
  
  - Check for result
  
  ```bash
  oc get pods -n demo
  ```
  
  - Sample result
  
  ```bash
  NAME                          READY   STATUS             RESTARTS     AGE
  backend-v5-65569d96b9-ht5zl   0/1     CrashLoopBackOff   1 (8s ago)   13s
  backend-v6-794c9fc748-hgpl2   0/1     ImagePullBackOff   0            13s
  ```
  
- Check for alerts on Notifications menu
    
    ![](images/alerts-notification.png)

- Administrator -> Overview
        
    ![](images/pod-stuck-alert-overview.png)

<!-- - For User Workload Monitoring
    
    ![](images/pod-stuck-alert-dev-console.png) -->

- Check for details of an alert
        
    ![](images/pod-stuck-crashloopbackoff.png)

### OOMKilled

  - Create following [memory-hungry](manifests/memory-hungry.yaml) deployments. These deployments intentionally put pods into error state.
  
  ```bash
  oc create -f manifests/memory-hungry.yaml -n demo
  ```
  - Check for result
  
    ```bash
    oc get pods -n demo
    ```

  - Get route to access memory-hungry app
    
    ```bash
    HUNGER=https://$(oc get route memory-hungry -n demo -o jsonpath='{.spec.host}')
    ```

  - Run following command
    
    ```bash
    curl -s $HUNGER/eat/6
    ```

  - Check application log
    
    ```bash
    2022-10-25 09:03:05,745 INFO  [io.quarkus] (main) leak 1.0.0-SNAPSHOT native (powered by Quarkus 2.13.1.Final) started in 0.202s. Listening on: http://0.0.0.0:8080
    2022-10-25 09:03:05,745 INFO  [io.quarkus] (main) Profile prod activated.
    2022-10-25 09:03:05,745 INFO  [io.quarkus] (main) Installed features: [cdi, resteasy, smallrye-context-propagation, smallrye-health, smallrye-metrics, smallrye-openapi, vertx]
    2022-10-25 09:55:54,697 INFO  [com.exa.HungryResource] (executor-thread-0) Prepare meal for dish no. 1
    2022-10-25 09:55:54,845 INFO  [com.exa.HungryResource] (executor-thread-0) Allocated 10485760 bytes
    2022-10-25 09:55:54,845 INFO  [com.exa.HungryResource] (executor-thread-0) Prepare meal for dish no. 2
    2022-10-25 09:55:55,141 INFO  [com.exa.HungryResource] (executor-thread-0) Allocated 10485760 bytes
    2022-10-25 09:55:55,142 INFO  [com.exa.HungryResource] (executor-thread-0) Prepare meal for dish no. 3
    2022-10-25 09:55:55,346 INFO  [com.exa.HungryResource] (executor-thread-0) Allocated 10485760 bytes
    2022-10-25 09:55:55,346 INFO  [com.exa.HungryResource] (executor-thread-0) Prepare meal for dish no. 4
    2022-10-25 09:55:55,641 INFO  [com.exa.HungryResource] (executor-thread-0) Allocated 10485760 bytes
    2022-10-25 09:55:55,641 INFO  [com.exa.HungryResource] (executor-thread-0) Prepare meal for dish no. 5
    ```
  - Check for alert in console

    ![](images/OOMKilled-alert.png)
    
  - Check pod with oc *get pod <pod name> -o yaml*
    
    ```yaml
      containerStatuses:
        - containerID: cri-o://c3cb6a9b2a967f35bda906e5e20b1d22c1c4f8f1dc15d2e797618e1f8438f7fb
          image: quay.io/voravitl/leak:native
          imageID: quay.io/voravitl/leak@sha256:f74d7653c2ebf71144f16019143b9849fff3f3491e4ec199fab6db51dab02b8f
          lastState:
            terminated:
              containerID: cri-o://08f70b1f69bc00906edaa17241d300abf2df4b356c13b7dd1896eae5b0bb6760
              exitCode: 137
              finishedAt: "2022-11-03T07:03:06Z"
              reason: OOMKilled
              startedAt: "2022-11-03T06:56:55Z"
    ```

## Alert with LINE

- Login to [LINE Developer](https://developers.line.biz/) and create Channel
- Deploy LINE BOT app
  
  ```bash
  oc new-project line-alert
  oc create -f manifests/line-bot.yaml -n line-alert
  ```

  Verify deployment

    ![](images/line-bot-alert-pod.png)

- Update line-bot deployment environment variable *API_LINE_TOKEN* with your channel access token

  Channel access token

  ![](images/line-channel-access-token.png)
    
  Update Environment variable 
  
  - Developer Console

    ![](images/line-bot-api-line-token.png)

  - CLI

    ```bash
    oc set env -n line-alert deployment/line-bot API_LINE_TOKEN-
    oc set env -n line-alert deployment/line-bot API_LINE_TOKEN=$API_LINE_TOKEN
    ```

- Update your Channel's Webhook with line-bot route
  
  Webhook URL 

  ```bash
  LINE_WEBHOOK=https://$(oc get route line-bot -n line-alert -o jsonpath='{.spec.host}')/webhook
  echo $LINE_WEBHOOK
  ```
  
  Configure Line BOT Webhook to your channel

    ![](images/line-developer-webhook.png)

 
  Send some message to your LINE BOT and check line-bot pod's log

    ```bash
    2022-09-06 06:47:14,766 INFO  [com.vor.LineBotResource] (executor-thread-0) Message Type: text
    2022-09-06 06:47:14,766 INFO  [com.vor.LineBotResource] (executor-thread-0) Message: Hi
    2022-09-06 06:47:14,766 INFO  [com.vor.LineBotResource] (executor-thread-0) userId: U*************, userType: user
    2022-09-06 06:47:14,767 INFO  [com.vor.LineBotResource] (executor-thread-0) replyToken: 0a5b7*********
    ```

- Register your LINE account to receiving alert by send message **register** to LINE BOT

    ![](images/line-bot-register.jpg)

    line-bot pod's log
    
    ```log
    2022-09-06 07:14:04,915 INFO [com.vor.LineBotResource] (executor-thread-0) destination: Uef7db62e42ed955b58d9810f64955806
    2022-09-06 07:14:04,916 INFO [com.vor.LineBotResource] (executor-thread-0) Message Type: text
    2022-09-06 07:14:04,916 INFO [com.vor.LineBotResource] (executor-thread-0) Message: Register
    2022-09-06 07:14:07,142 INFO [com.vor.LineBotResource] (executor-thread-0) Register user: U*************
    2022-09-06 07:14:07,143 INFO [com.vor.LineBotResource] (executor-thread-0) userId: U*************, userType: user
    2022-09-06 07:14:07,143 INFO [com.vor.LineBotResource] (executor-thread-0) replyToken: 741b1*********
    ```

- Configure Alert Manger Webhook
  
  - Administrator Console, Administration->Cluster Settings->Configuration and select *Alertmanager*

      ![](images/admin-console-config-alertmanager.png)
  
  - Create Receiver

      ![](images/line-webhook-receiver.png)

  - Check that PrometheusRule [pod-stuck](manifests/pod-stuck-alerts.yaml) contains label receiver with value equals to line for each alert

    ```yaml
    - alert: PodStuckErrImagePull
      annotations:
        message: Pod  {{ $labels.pod }}  in project {{ $labels.namespace }} project stuck at ErrImagePull
        description: Pod  {{ $labels.pod }}  in project {{ $labels.namespace }} project stuck at ErrImagePull
      expr: kube_pod_container_status_waiting_reason{reason="ErrImagePull"} == 1 
      for: 30s
      labels:
        severity: critical
        receiver: 'line'
    ```

- Create deployment with CrashLoopBackoff

    ```bash
    oc create -f manifests/pod-stuck -n demo
    watch oc get pods -n demo
    ```

- Check LINE message
  
  ![](images/line-alert-crashloopbackoff.png)


### LINE BOT Configuration

Use following enviroment variables to configure LINE BOT

  | Variable                                 | Description                                                          |
  |------------------------------------------|----------------------------------------------------------------------|
  | APP_LINE_TOKEN                           | LINE Channel Token                                                   |
  | QUARKUS_LOG_CATEGORY__COM_VORAVIZ__LEVEL | Set to DEBUG if you want to log whole JSON message from AlertManager |
  | APP_ALERT_ANNOTATIONS                    | List of attributes from Annotations to including in message          |


Alert Rule annotaions

  ```yaml
  - alert: PodStuckCrashLoopBackOff
        annotations:
          summary: CrashLoopBackOff in project {{ $labels.namespace }}
          message: Pod  {{ $labels.pod }}  in project {{ $labels.namespace }} project stuck at CrashLoopBackOff
          description: Pod  {{ $labels.pod }}  in project {{ $labels.namespace }} project stuck at CrashLoopBackOff
  ```