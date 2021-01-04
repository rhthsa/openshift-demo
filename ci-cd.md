# CI/CD

<!-- TOC -->

- [CI/CD](#ci/cd)
  - [Prerequisites](#prerequisites)
  - [Azure DevOps](#azure-devops)
  - [Deploy Back App](#deploy-back-app)
  - [Deploy Front App](#deploy-front-app)
  - [Prepare Harbor On Kubernetes/OpenShift](#prepare-harbor-on-kubernetes/openshift)
  - [Prepare Azure DevOps Service Connection](#prepare-azure-devops-service-connection)
  - [Azure pipelines](#azure-pipelines)

<!-- /TOC -->

## Prerequisites
- Openshift 4.6 Cluster
- Oepnshift User with Admin Permission
- Azure DevOps Project
- Harbor Container Registry
- Postman / K6 for Test

## Azure DevOps

- Azure Devops Project

  https://dev.azure.com/chatapazar0583/BOTDemoApplication.Front

- Azure Repo

    `user`: chatapazar

    `PAT`: stpkr4cpnprrgxmx66zg7qlgqycjlmzwv5w4d2go7uvq3xdc5tea

    `BOTDemoApplication.Front Repository`: https://chatapazar0583@dev.azure.com/chatapazar0583/BOTDemoApplication.Front/_git/BOTDemoApplication.Front

    `BOTDemoApplication.Back Repository` : https://chatapazar0583@dev.azure.com/chatapazar0583/BOTDemoApplication.Front/_git/BOTDemoApplication.Back


## Deploy Back App

deploy source code from azure repo with openshift s2i

login, new project call 'bot'
```
oc login
oc new-project bot
```

prepare secret for azure repo
```
oc create secret generic azure-repo --from-literal=username=chatapazar --from-literal=password=stpkr4cpnprrgxmx66zg7qlgqycjlmzwv5w4d2go7uvq3xdc5tea --type=kubernetes.io/basic-auth
oc secrets link builder azure-repo
```

deploy back app [back.yaml](ci-cd/back.yaml)
```
oc create -f back.yaml
oc expose svc/back
```

## Deploy Front App

set current project to bot
```
oc project bot
```

create secret for harbor
```
oc create secret docker-registry myharbor --docker-username=chatapazar --docker-server=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com --docker-password=Optimus9a
oc secrets link default myharbor --for=pull --namespace=bot
```

For private Container Registry and Self Sign Cert, if use CA go to create imagestream

get ca.crt with openssl
```
openssl s_client -connect ocr.apps.cluster-b3e9.b3e9.example.opentlc.com:443 -showcerts </dev/null 2>/dev/null|openssl x509 -outform PEM > ca.crt
```
or
get cert with firefox (ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/v2 --> select both PEM & PEM chain)

create configmap and add trust ca to openshift (both PEM & PEM chain
```
oc create configmap harbor-registry --from-file=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com=ca1.crt -n openshift-config
oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"harbor-registry"}}}' --type=merge

oc create configmap registry-config --from-file=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com=ca.crt -n openshift-config
oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"registry-config"}}}' --type=merge
```

create imagestream
```
oc import-image bot/front-blue:latest --from=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/bot/botdemoapp.front:20201230.32 --confirm
oc import-image bot/front-green:latest --from=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/bot/botdemoapp.front:20201230.32 --confirm
```

update imagestream, if you need change version of image in openshift
```
oc tag ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/bot/botdemoapp.front:20201230.32 bot/front-blue:latest
oc tag ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/bot/botdemoapp.front:20201230.32 bot/front-green:latest
```

deploy front-blue, front-green and expose route to front-blue [front-blue.yaml](ci-cd/front-blue.yaml), [front-green.yaml](ci-cd/front-green.yaml)
```
oc create -f front-blue.yaml
oc create -f front-green.yaml
oc patch dc front-green -p "{\"spec\":{\"replicas\":0}}" -n bot

oc expose service front-blue -l name=front --name=front
```

Environment of front app, can change in front-blue.yaml and front-green.yaml
```
ITERATION_COUNT=1000
BACKEND_URL=http://back:8080/api/values/back
ASPNETCORE_URLS=http://*:8080
```

## Prepare Harbor On Kubernetes/OpenShift

create new project 'harbor'
```
oc new-project harbor
oc adm policy add-scc-to-group anyuid system:authenticated
```

install harbor with helm: https://computingforgeeks.com/install-harbor-image-registry-on-kubernetes-openshift-with-helm-chart/

```
helm install harbor harbor/harbor \
--set persistence.persistentVolumeClaim.registry.size=10Gi \
--set persistence.persistentVolumeClaim.chartmuseum.size=5Gi \
--set persistence.persistentVolumeClaim.database.size=5Gi \
--set externalURL=https://ocr.apps.cluster-b3e9.b3e9.example.opentlc.com \
--set expose.ingress.hosts.core=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com \
--set expose.ingress.hosts.notary=notary.apps.cluster-b3e9.b3e9.example.opentlc.com \
--set harborAdminPassword=H@rb0rAdm \
-n harbor
```

- change externalURL to https://ocr.{openshift-clustername}
- change expose.ingress.hosts.core to ocr.{openshift-clustername}
- change expose.ingress.hosts.notary to notary.{openshift-clustername}
- create project bot
- create user for access harbor


## Prepare Azure DevOps Service Connection

Service Connection: openshift

select new service connection select type Openshift
- Authentication method: Token Based Authentication
- Server URL: such as https://api.cluster-b3e9.b3e9.example.opentlc.com:6443
- accept untrusted SSL: checked
- api token: such as sha256~fF0TCW0az6FMJ6232dJAxdhX4lqZo-bkYdbfFKwv_Zw
- service connection name: openshift
- grant access permission to all pipelines: checked

Service Connection: harbor

select new service connection select type docker registry
- registry type: Others
- Docker Registry: such as https://ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/
- Docker ID: harbor user
- Docker Password: harbor password
- service connection name: harbor
- grant access permission to all pipelines: checked


## Azure pipelines

Pipelines: BOTDemoApplication.Front

URL: https://dev.azure.com/chatapazar0583/_git/BOTDemoApplication.Front?path=%2Fazure-pipelines-1.yml

current step in ci or pipeline
- install .ned sdk 2.2 for test project (app use 2.1, test use 2.2 ???)
- restore package/library with azure artifacts
- build
- unit test --> publish to Azure DevOps
- code coverage with cobertura --> publish to Azure DevOps
- publish
- login registry.redhat.io for pull ubi8/dotnet-21-runtime
- build image
- install trivy, scan image
- harbor login, with self sign of harbor, need copy ca.crt to docker 
(such as /etc/docker/certs.d/ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/ca.crt ) in Azure DevOps agent 
and manual login, recommended use CA in Prod
- push image to harbor 

Releases: bot dev [botdev.json](ci-cd/botdev.json)

url: https://dev.azure.com/chatapazar0583/BOTDemoApplication.Front/_release?view=mine&_a=releases&definitionId=1

trigger from ci/pipeline or manual
stage 1: switch to new version
- setup oc command
- check current deployment and destination deployment
- switch from blue to green or green to blue
- switch route to new version
stage 2: scale down previous version
- can add approval for confirm 
- setup oc command
- scale down previous version

Test with postman script of BOT



   
