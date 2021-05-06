# CI/CD with Azure DevOps

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

  https://dev.azure.com/user/project

- Azure Repo

    `user`: chatapazar

    `PAT`: xxx

    `demo.Front Repository`: https://user@dev.azure.com/user/demo.Front/_git/demo.Front

    `demo.Back Repository` : https://user@dev.azure.com/user/demo.Front/_git/demo.Back

- Azure Artifact
    
    create new feed
    
    `name`: my-very-private-feed
    
    leave all default

## Deploy Back App

deploy source code from azure repo with openshift s2i

login, new project call 'test'
```
oc login
oc new-project test
```

prepare secret for azure repo
```
oc create secret generic azure-repo --from-literal=username=chatapazar --from-literal=password=xxx --type=kubernetes.io/basic-auth
oc secrets link builder azure-repo
```

deploy back app [back.yaml](ci-cd/back.yaml)
```
oc create -f back.yaml
oc expose svc/back
```

## Deploy Front App

set current project to test
```
oc project test
```

create secret for harbor
```
oc create secret docker-registry myharbor --docker-username=chatapazar --docker-server=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com --docker-password=xxx
oc secrets link default myharbor --for=pull --namespace=test
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
oc import-image test/front-blue:latest --from=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/test/testdemoapp.front:20201230.32 --confirm
oc import-image test/front-green:latest --from=ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/test/testdemoapp.front:20201230.32 --confirm
```

update imagestream, if you need change version of image in openshift
```
oc tag ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/test/testdemoapp.front:20201230.32 test/front-blue:latest
oc tag ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/test/testdemoapp.front:20201230.32 test/front-green:latest
```

deploy front-blue, front-green and expose route to front-blue [front-blue.yaml](ci-cd/front-blue.yaml), [front-green.yaml](ci-cd/front-green.yaml)
```
oc create -f front-blue.yaml
oc create -f front-green.yaml
oc patch dc front-green -p "{\"spec\":{\"replicas\":0}}" -n test

oc expose service front-blue -l name=front --name=front
```

Environment of front app, can change in front-blue.yaml and front-green.yaml
```
ITERATION_COUNT=1000
BACKEND_URL=http://back:8080/api/values/back
ASPNETCORE_URLS=http://*:8080
```

## Canary Deployment

create imagestream for canary
```
oc import-image test/front-main:latest --from=ocr.apps.cluster-852b.852b.example.opentlc.com/test/testdemoapp.front:20210105.5 --confirm
oc import-image test/front-sub:latest --from=ocr.apps.cluster-852b.852b.example.opentlc.com/test/testdemoapp.front:20210105.5 --confirm
```

create front-main dc
```
oc project test
oc create -f front-main.yaml
```

create front-sub dc
```
oc create -f front-sub.yaml
```

create route canary
```
oc create -f canary.yaml
```

test canary
manual run release canary in azure devops
```
curl http://canary-test.apps.cluster-852b.852b.example.opentlc.com/api/values/information
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
- create project test
- create user for access harbor


## Prepare Azure DevOps Service Connection

Service Connection: openshift

select new service connection, select type Openshift
- Authentication method: Token Based Authentication
- Server URL: such as https://api.cluster-b3e9.b3e9.example.opentlc.com:6443
- accept untrusted SSL: checked
- api token: such as sha256~fF0TCW0az6FMJ6232dJAxdhX4lqZo-bkYdbfFKwv_Zw
- service connection name: openshift
- grant access permission to all pipelines: checked

Service Connection: harbor

select new service connection, select type docker registry
- registry type: Others
- Docker Registry: such as https://ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/
- Docker ID: harbor user
- Docker Password: harbor password
- service connection name: harbor
- grant access permission to all pipelines: checked

Service Connection: fortify

select new service connection, select type fortify 
- authen mode: basic authen
- api url: https://api.trial.fortify.com
- portal url: https://trial.fortify.com
- username: chatapazar@gmail.com
- PAT: xxx
- Tenant ID: xxx
- connection name: fortify


## Azure pipelines

Pipelines: [sample-pipeline.yml](ci-cd/sample-pipeline.yml), [sample-pipeline-redhat-image.yml](ci-cd/sample-pipeline-redhat-image.yml)

current step in ci or pipeline
- install .net sdk 2.2 for test project (app use 2.1, test use 2.2 ???)
- restore package/library with azure artifacts
- build
- unit test --> publish to Azure DevOps
- code coverage with cobertura --> publish to Azure DevOps
- publish
- Option: scan code with fortify (use fortify on demand, don't have fortify scs license file)
- Option: login registry.redhat.io for pull ubi8/dotnet-21-runtime --> sample-pipeline-redhat-image.yml
- build image
- install trivy, scan image with trivy, publish resutl to Azure DevOps (test)
- harbor login, with self sign of harbor, need copy ca.crt to docker 
(such as /etc/docker/certs.d/ocr.apps.cluster-b3e9.b3e9.example.opentlc.com/ca.crt ) in Azure DevOps agent 
and manual login, recommended use CA in Prod
- push image to harbor 

Releases: [blue-green.json](ci-cd/blue-green.json), [canary.json](ci-cd/canary.json)

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

Test with postman script of Test

## Canary Deployment

change in front route with yaml 
```
spec:
  host: front-test.apps.cluster-852b.852b.example.opentlc.com
  to:
    kind: Service
    name: front-blue
    weight: 90
  alternateBackends:
    - kind: Service
      name: front-green
      weight: 10
  port:
    targetPort: 8080-tcp
  wildcardPolicy: None
```

or oc pathc
```
oc patch route frontend  -p '{"spec":{"to":{"weight":60}}}' -n project1 
oc patch route frontend --type='json' -p='[{"op":"replace","path":"/spec/alternateBackends/0/weight","value":40}]' -n project1 
```

## Use Openshift Internal Registry

```
oc create imagestream demofront -n test
oc create imagestream demoapp -n test

oc login with plugin
docker login -u opentlc-mgr -p $(oc whoami -t) default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com
docker push default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com/test/demofront:xxx
docker push default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com/test/demoapp:xxx

oc tag test/demofront:xxx test/demofront:latest
oc tag test/demoapp:xxx test/demoapp:latest
```
- create imagestream
- login openshift
- login docker to openshift internal registry with token
- push image
- tag image stream


## Step Demo

- preset architecture prod vs demo
- preset ocp console / usage / login / user management
- preset harbor / usage / project / user management / scan manual/auto / set cve block pull / set cve whitelist / set auto scan on push
- present pipeline / release
- scan code with fortify
- scan image in pipeline , change show image from red hat , run with red hat image
- blue green / deploy
- canary --> example --> see again in service mesh , network deploy section
- detail of [openshift route deployment streategy](openshift-route.md)   

## openshift internal registry

- add permission to user for internal registry
```
oc adm policy add-role-to-user system:registry <intended_user> -n <namespace/project>
oc adm policy add-role-to-user system:image-builder <intended_user> -n <namespace/project>
## or for cluster-wide access...
oc adm policy add-cluster-role-to-user system:registry <intended_user>
oc adm policy add-cluster-role-to-user system:image-builder <intended_user>
```
example
```
oc login (with user1)
oc new-project user1
oc login (with user2)
oc new-project user2
oc login (with admin)
oc adm policy add-role-to-user system:registry user1 -n user1
oc adm policy add-role-to-user system:image-builder user2 -n user2
```
- test rbac internal registry
```
oc login (with user1)
docker login -u user1 -p $(oc whoami -t) default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com
docker pull hello-world
docker tag  hello-world:latest default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com/user1/hello-world:latest
docker push default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com/user1/hello-world:latest
#view imagestream in openshift project user1
docker rmi -f $(docker images -a -q)
docker images
docker logout default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com
oc login (with user2)
docker login -u user2 -p $(oc whoami -t) default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com
docker pull default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com/user1/hello-world:latest
#view result error
docker logout default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com
oc login (with user1)
docker login -u user1 -p $(oc whoami -t) default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com
docker pull default-route-openshift-image-registry.apps.cluster-852b.852b.example.opentlc.com/user1/hello-world:latest
#view result success
```
- prune image https://docs.openshift.com/container-platform/4.4/applications/pruning-objects.html#pruning-images_pruning-objects
