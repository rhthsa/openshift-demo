#!/bin/sh
START_BUILD=$(date +%s)
SONARQUBE_VERSION=7.9.2
#export NEXUS_VERSION=3.19.1
#export NEXUS_VERSION=3.18.1
#NEXUS_VERSION=3.30.0
NEXUS_VERSION=3.25.1
CICD_PROJECT=ci-cd
DEV_PROJECT=dev
PROD_PROJECT=prod
STAGE_PROJECT=stage
UAT_PROJECT=uat
NEXUS_PVC_SIZE="300Gi"
JENKINS_PVC_SIZE="10Gi"
SONAR_PVC_SIZE="10Gi"
CICD_NEXUS_USER=jenkins
CICD_NEXUS_USER_SECRET=$(echo ${CICD_NEXUS_USER}|base64 -)
function check_pod(){
    sleep 15
    READY="NO"
    while [ $READY = "NO" ];
    do
        clear
        #echo "Wait for $1 pod to sucessfully start"
        MESSAGE=$(oc get pods  -n ${CICD_PROJECT}| grep $1 | grep -v deploy)
        STATUS=$(echo ${MESSAGE}| awk '{print $2}')
        if [ $(echo -n ${MESSAGE} | wc -c) -gt 0 ];
            then
            if [ ${STATUS} = "1/1" ];
            then
                READY="YES"
            else 
                echo "Current Status: ${MESSAGE}"
                cat $1.txt
                sleep 3
                clear
                echo "Current Status: ${MESSAGE}"
                cat wait.txt
                sleep 2

            fi
        else
            oc get pods -n ${CICD_PROJECT} | grep $1
            sleep 5
        fi
    done
}
oc patch image.config.openshift.io/cluster -p \
'{"spec":{"registrySources":{"insecureRegistries":["nexus-registry.ci-cd.svc.cluster.local"]}}}' --type='merge'
oc project ${CICD_PROJECT}
#--as-deployment-config=true 
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi \
--param VOLUME_CAPACITY=${JENKINS_PVC_SIZE} --param DISABLE_ADMINISTRATIVE_MONITORS=true
oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m
oc label dc jenkins app.kubernetes.io/name=Jenkins -n ${CICD_PROJECT}
oc label dc jenkins app.openshift.io/runtime=jenkins -n ${CICD_PROJECT}
# No need to wait for jenkins to start
check_pod "jenkins"
oc new-app sonatype/nexus3:${NEXUS_VERSION} --name=nexus -n ${CICD_PROJECT}
oc create route edge nexus --service=nexus --port=8081
oc rollout pause deployment nexus -n ${CICD_PROJECT}
#oc patch deployment nexus --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${CICD_PROJECT}
oc set resources deployment nexus --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m -n ${CICD_PROJECT}
oc set volume deployment/nexus --remove --confirm -n ${CICD_PROJECT}
oc set volume deployment/nexus --add --overwrite --name=nexus-pv-1 \
--mount-path=/nexus-data/ --type persistentVolumeClaim \
--claim-name=nexus-pvc --claim-size=${NEXUS_PVC_SIZE} -n ${CICD_PROJECT}
oc set probe deployment/nexus --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok -n ${CICD_PROJECT}
oc set probe deployment/nexus --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/ -n ${CICD_PROJECT}
oc label deployment nexus app.kubernetes.io/part-of=Registry -n ${CICD_PROJECT}
oc rollout resume deployment nexus -n ${CICD_PROJECT}
check_pod "nexus"
oc new-app  --template=postgresql-persistent \
--param POSTGRESQL_USER=sonar \
--param POSTGRESQL_PASSWORD=sonar \
--param POSTGRESQL_DATABASE=sonar \
--param VOLUME_CAPACITY=${SONAR_PVC_SIZE} \
--labels=app=sonarqube_db,app.openshift.io/runtime=postgresql
check_pod "postgresql"
oc new-app  --docker-image=quay.io/gpte-devops-automation/sonarqube:$SONARQUBE_VERSION --env=SONARQUBE_JDBC_USERNAME=sonar --env=SONARQUBE_JDBC_PASSWORD=sonar --env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar --labels=app=sonarqube
oc rollout pause deployment sonarqube
oc label deployment sonarqube app.kubernetes.io/part-of=Code-Quality -n ${CICD_PROJECT}
#oc expose svc sonarqube
oc create route edge sonarqube --service=sonarqube --port=9000
oc set volume deployment/sonarqube --add --overwrite --name=sonarqube-volume-1 --mount-path=/opt/sonarqube/data/ --type persistentVolumeClaim --claim-name=sonarqube-pvc --claim-size=1Gi
oc set resources deployment sonarqube --limits=memory=3Gi,cpu=2 --requests=memory=2Gi,cpu=1
#oc patch deployment sonarqube --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'
oc set probe deployment/sonarqube --liveness --failure-threshold 3 --initial-delay-seconds 40 --get-url=http://:9000/about
oc set probe deployment/sonarqube --readiness --failure-threshold 3 --initial-delay-seconds 20 --get-url=http://:9000/about
oc patch deployment/sonarqube --type=merge -p '{"spec": {"template": {"metadata": {"labels": {"tuned.openshift.io/elasticsearch": "true"}}}}}'
oc label dc postgresql app.kubernetes.io/part-of=Code-Quality -n ${CICD_PROJECT}
oc label dc postgresql app.kubernetes.io/name=posgresql -n ${CICD_PROJECT}
oc rollout resume deployment sonarqube
check_pod "sonarqube"
export NEXUS_POD=$(oc get pods | grep nexus | grep -v deploy | awk '{print $1}')
oc cp $NEXUS_POD:/nexus-data/etc/nexus.properties nexus.properties
echo nexus.scripts.allowCreation=true >>  nexus.properties
oc cp nexus.properties $NEXUS_POD:/nexus-data/etc/nexus.properties
rm -f nexus.properties
oc delete pod $NEXUS_POD
echo "Wait 10 sec..."
sleep 10
check_pod "nexus"
export NEXUS_POD=$(oc get pods | grep nexus | grep -v deploy | awk '{print $1}')
export NEXUS_PASSWORD=$(oc exec $NEXUS_POD -- cat /nexus-data/admin.password)
CICD_NEXUS_PASSWORD=${NEXUS_PASSWORD}-$(date +%s)
# https://raw.githubusercontent.com/redhat-gpte-devopsautomation/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
./setup_nexus3.sh admin $NEXUS_PASSWORD https://$(oc get route nexus --template='{{ .spec.host }}') ${CICD_NEXUS_USER} ${CICD_NEXUS_PASSWORD}
echo "expose port 5000 for container registry"
oc expose deployment nexus --port=5000 --name=nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000
CICD_NEXUS_PASSWORD_SECRET=$(echo ${CICD_NEXUS_PASSWORD}|base64 -)
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
     --docker-password=$CICD_NEXUS_PASSWORD \
     --docker-email=unused \
     -n $project
     oc create secret docker-registry nexus-svc-registry --docker-server=nexus-registry.svc.cluster.local:5000 \
     --docker-username=$CICD_NEXUS_USER \
     --docker-password=$CICD_NEXUS_PASSWORD \
     --docker-email=unused \
     -n $project
    #oc get secret nexus-credential -o yaml -n $CICD_PROJECT | grep -v '^\s*namespace:\s' | oc create -n $project -f -
done

for project in "${PROJECTS[@]}"
do
    echo "Link secrets for $project"
    oc secrets link default nexus-registry -n $project --for=pull
    oc secrets link default nexus-svc-registry -n $project --for=pull
done
oc secrets link builder nexus-registry -n $CICD_PROJECT
oc secrets link builder nexus-svc-registry -n $CICD_PROJECT

# oc patch image.config.openshift.io/cluster \
# --type='json' \
# -p='[{"op": "add", "path": "/spec/registrySources/insecureRegistries/-", "value": "nexus-registry.ci-cd.svc.cluster.local" }]'

# spec:
#   registrySources:
#     insecureRegistries:
#     - nexus-registry.ci-cd.svc.cluster.local


END_BUILD=$(date +%s)
BUILD_TIME=$(expr ${END_BUILD} - ${START_BUILD})
clear
echo "Jenkins URL = $(oc get route jenkins -n ${CICD_PROJECT} -o jsonpath='{.spec.host}')"
echo "NEXUS URL = $(oc get route nexus -n ${CICD_PROJECT} -o jsonpath='{.spec.host}') "
echo "NEXUS Password = ${NEXUS_PASSWORD}"
echo "Nexus password is stored at bin/nexus_password.txt"
echo "Jenkins will use user/password store in secret nexus-credential to access nexus"
echo ${NEXUS_PASSWORD} > nexus_password.txt
echo ${CICD_NEXUS_PASSWORD} >> nexus_password.txt
echo "Record this password and change it via web console"
echo "Start build pipeline and deploy to dev project by run start_build_pipeline.sh"
echo "Elasped time to build is $(expr ${BUILD_TIME} / 60 ) minutes"
# echo "Edit image.config.openshift.io/cluster with following spec"
# echo "spec:"
# echo "  registrySources:"
# echo "    insecureRegistries:"
# echo "    - nexus-registry.ci-cd.svc.cluster.local"
