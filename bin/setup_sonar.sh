#!/bin/bash
START_BUILD=$(date +%s)
SONARQUBE_VERSION=lts-community
CICD_PROJECT=ci-cd
DEV_PROJECT=dev
PROD_PROJECT=prod
STAGE_PROJECT=stage
UAT_PROJECT=uat
SONAR_PVC_SIZE="10Gi"
oc project $CICD_PROJECT
echo "Setup PostgreSQL for SonarQube..."
oc new-app  --template=postgresql-persistent \
--param POSTGRESQL_USER=sonar \
--param POSTGRESQL_PASSWORD=sonar \
--param POSTGRESQL_DATABASE=sonar \
--param VOLUME_CAPACITY=${SONAR_PVC_SIZE} \
--labels=app=sonarqube_db,app.openshift.io/runtime=postgresql
oc wait --for=condition=Ready --timeout=300s pods -l name=postgresql -n $CICD_PROJECT
# check_pod "postgresql"
clear;echo "Setup SonarQube..."
oc new-app  --image=sonarqube:$SONARQUBE_VERSION --env=SONARQUBE_JDBC_USERNAME=sonar --env=SONARQUBE_JDBC_PASSWORD=sonar --env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar --labels=app=sonarqube
oc rollout pause deployment sonarqube
oc annotate deployment sonarqube 'app.openshift.io/connects-to=[{"apiVersion":"apps.openshift.io/v1","kind":"DeploymentConfig","name":"postgresql"}]'
oc label deployment sonarqube app.kubernetes.io/part-of=Code-Quality -n ${CICD_PROJECT}
#oc expose svc sonarqube
oc create route edge sonarqube --service=sonarqube --port=9000
oc set volume deployment/sonarqube --add --overwrite --name=sonarqube-volume-1 --mount-path=/opt/sonarqube/data/ --type persistentVolumeClaim --claim-name=sonarqube-pvc --claim-size=1Gi
oc set resources deployment sonarqube --limits=memory=3Gi,cpu=2 --requests=memory=2Gi,cpu=1
oc set probe deployment/sonarqube --liveness --failure-threshold 3 --initial-delay-seconds 40 --get-url=http://:9000/about
oc set probe deployment/sonarqube --readiness --failure-threshold 3 --initial-delay-seconds 20 --get-url=http://:9000/about
oc patch deployment/sonarqube --type=merge -p '{"spec": {"template": {"metadata": {"labels": {"tuned.openshift.io/elasticsearch": "true"}}}}}'
oc label dc postgresql app.kubernetes.io/part-of=Code-Quality -n ${CICD_PROJECT}
oc label dc postgresql app.kubernetes.io/name=posgresql -n ${CICD_PROJECT}
oc rollout resume deployment sonarqube
oc wait --for=condition=Ready --timeout=300s pods -l app=sonarqube -n $CICD_PROJECT
echo "Setup SonarQube completed"
echo "https://$(oc get route sonarqube -o jsonpath='{.spec.host}' -n $CICD_PROJECT)"
