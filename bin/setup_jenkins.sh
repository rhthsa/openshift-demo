#!/bin/bash
START_BUILD=$(date +%s)
CICD_PROJECT=ci-cd
DEV_PROJECT=dev
PROD_PROJECT=prod
STAGE_PROJECT=stage
UAT_PROJECT=uat
JENKINS_PVC_SIZE="10Gi"
CICD_NEXUS_USER=jenkins
CICD_NEXUS_USER_SECRET=$(echo $CICD_NEXUS_USER|base64)
oc project ${CICD_PROJECT}
clear;echo "Setup Jenkins..."
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi \
--param VOLUME_CAPACITY=${JENKINS_PVC_SIZE} --param DISABLE_ADMINISTRATIVE_MONITORS=true
oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m
oc label dc jenkins app.kubernetes.io/name=Jenkins -n $CICD_PROJECT
oc label dc jenkins app.openshift.io/runtime=jenkins -n $CICD_PROJECT
oc wait --for=condition=Ready --timeout=300s pods -l name=jenkins -n $CICD_PROJECT
NEXUS_PASSWORD=$(cat nexus_password.txt|tail -n 1)
CICD_NEXUS_PASSWORD_SECRET=$(echo ${NEXUS_PASSWORD}|base64 -)
clear;echo "Create secrets for Jenkins to access Nexus"
oc create -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: nexus-credential
type: Opaque 
data:
  username: ${CICD_NEXUS_USER_SECRET}
  password: ${CICD_NEXUS_PASSWORD_SECRET}
EOF

NEXUS_REGISTRY=$(oc get route nexus-registry -n ${CICD_PROJECT} -o jsonpath='{.spec.host}')
PROJECTS=($CICD_PROJECT $DEV_PROJECT $STAGE_PROJECT $UAT_PROJECT $PROD_PROJECT)
for project in  "${PROJECTS[@]}"
do
    echo "Create registry secret for $project"
     oc create secret docker-registry nexus-registry --docker-server=$NEXUS_REGISTRY \
     --docker-username=$CICD_NEXUS_USER \
     --docker-password=$NEXUS_PASSWORD \
     --docker-email=unused \
     -n $project
     oc create secret docker-registry nexus-svc-registry --docker-server=nexus-registry.svc.cluster.local:5000 \
     --docker-username=$CICD_NEXUS_USER \
     --docker-password=$NEXUS_PASSWORD \
     --docker-email=unused \
     -n $project
    #oc get secret nexus-credential -o yaml -n $CICD_PROJECT | grep -v '^\s*namespace:\s' | oc create -n $project -f -
done
clear;echo "Link Nexus' secret to puller"
for project in "${PROJECTS[@]}"
do
    echo "Link secrets for $project"
    oc secrets link default nexus-registry -n $project --for=pull
    oc secrets link default nexus-svc-registry -n $project --for=pull
done
clear;echo "Link Nexus' secret to builder"
oc secrets link builder nexus-registry -n $CICD_PROJECT
oc secrets link builder nexus-svc-registry -n $CICD_PROJECT
oc import-image maven36-with-tools --from=quay.io/voravitl/maven36-with-tools --all --confirm -n $CICD_PROJECT
END_BUILD=$(date +%s)
BUILD_TIME=$(expr ${END_BUILD} - ${START_BUILD})
clear
echo "Jenkins URL = $(oc get route jenkins -n ${CICD_PROJECT} -o jsonpath='{.spec.host}')"
echo "Jenkins will use user/password store in secret nexus-credential to access nexus"
echo "Elasped time to build is $(expr ${BUILD_TIME} / 60 ) minutes"
