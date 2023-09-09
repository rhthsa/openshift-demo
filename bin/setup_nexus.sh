START_BUILD=$(date +%s)
SONARQUBE_VERSION=7.9.2
NEXUS_VERSION=3.57.1
CICD_PROJECT=ci-cd
DEV_PROJECT=dev
PROD_PROJECT=prod
STAGE_PROJECT=stage
UAT_PROJECT=uat
NEXUS_PVC_SIZE="300Gi"
JENKINS_PVC_SIZE="10Gi"
SONAR_PVC_SIZE="10Gi"
CICD_NEXUS_USER=jenkins
CICD_NEXUS_USER_SECRET=$(echo $CICD_NEXUS_USER|base64)

function add_nexus3_npmproxy_repo() {
  local _REPO_ID=$1
  local _REPO_URL=$2
  local _NEXUS_USER=$3
  local _NEXUS_PWD=$4
  local _NEXUS_URL=$5

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_REPO_ID",
  "type": "groovy",
  "content": "repository.createNpmProxy('$_REPO_ID','$_REPO_URL')"
}
EOM

  curl -k -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -k -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
}

function add_nexus3_nugetproxy_repo() {
  local _REPO_ID=$1
  local _REPO_URL=$2
  local _NEXUS_USER=$3
  local _NEXUS_PWD=$4
  local _NEXUS_URL=$5

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_REPO_ID",
  "type": "groovy",
  "content": "repository.createNugetProxy('$_REPO_ID','$_REPO_URL')"
}
EOM

  curl -k -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -k -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
}

#
# Add a Proxy Repo to Nexus3
# add_nexus3_proxy_repo [repo-id] [repo-url] [nexus-username] [nexus-password] [nexus-url]
#
function add_nexus3_proxy_repo() {
  local _REPO_ID=$1
  local _REPO_URL=$2
  local _NEXUS_USER=$3
  local _NEXUS_PWD=$4
  local _NEXUS_URL=$5

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_REPO_ID",
  "type": "groovy",
  "content": "repository.createMavenProxy('$_REPO_ID','$_REPO_URL')"
}
EOM

  curl -k  -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -k  -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
}

#
# Add a Release Repo to Nexus3
# add_nexus3_release_repo [repo-id] [nexus-username] [nexus-password] [nexus-url]
#
function add_nexus3_release_repo() {
  local _REPO_ID=$1
  local _NEXUS_USER=$2
  local _NEXUS_PWD=$3
  local _NEXUS_URL=$4

  # Repository createMavenHosted(final String name,
  #                                final String blobStoreName,
  #                                final boolean strictContentTypeValidation,
  #                                final VersionPolicy versionPolicy,
  #                                final WritePolicy writePolicy,
  #                                final LayoutPolicy layoutPolicy);

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_REPO_ID",
  "type": "groovy",
  "content": "import org.sonatype.nexus.blobstore.api.BlobStoreManager\nimport org.sonatype.nexus.repository.storage.WritePolicy\nimport org.sonatype.nexus.repository.maven.VersionPolicy\nimport org.sonatype.nexus.repository.maven.LayoutPolicy\nrepository.createMavenHosted('$_REPO_ID',BlobStoreManager.DEFAULT_BLOBSTORE_NAME, false, VersionPolicy.RELEASE, WritePolicy.ALLOW, LayoutPolicy.PERMISSIVE)"
}
EOM

  curl -k  -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -k  -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
}

#
# add_nexus3_group_proxy_repo [comma-separated-repo-ids] [group-id] [nexus-username] [nexus-password] [nexus-url]
#
function add_nexus3_group_proxy_repo() {
  local _REPO_IDS=$1
  local _GROUP_ID=$2
  local _NEXUS_USER=$3
  local _NEXUS_PWD=$4
  local _NEXUS_URL=$5

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_GROUP_ID",
  "type": "groovy",
  "content": "repository.createMavenGroup('$_GROUP_ID', '$_REPO_IDS'.split(',').toList())"
}
EOM

  curl -k  -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -k  -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_GROUP_ID/run"
}

#
# Add a Docker Registry Repo to Nexus3
# add_nexus3_docker_repo [repo-id] [repo-port] [nexus-username] [nexus-password] [nexus-url]
#
function add_nexus3_docker_repo() {
  local _REPO_ID=$1
  local _REPO_PORT=$2
  local _NEXUS_USER=$3
  local _NEXUS_PWD=$4
  local _NEXUS_URL=$5

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_REPO_ID",
  "type": "groovy",
  "content": "repository.createDockerHosted('$_REPO_ID',$_REPO_PORT,null)"
}
EOM

  curl -k  -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -k  -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
}

function add_nexus3_user() {
  local _JENKINS=$4
  local _PWD=$5
  local _NEXUS_USER=$1
  local _NEXUS_PWD=$2
  local _NEXUS_URL=$3

  read -r -d '' _USER_JSON << EOM
{
  "userId": "${_JENKINS}",
  "firstName": "${_JENKINS}",
  "lastName": "CI/CD",
  "emailAddress": "${_JENKINS}@example.com",
  "password": "${_PWD}",
  "status": "active",
  "roles": [
    "nx-admin"
  ]
}
EOM
  curl -k  -v  -H "accept: application/json" -H "Content-Type: application/json" -d "$_USER_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/beta/security/users"
}

function config_nexus3_realms() {
  local _NEXUS_USER=$1
  local _NEXUS_PWD=$2
  local _NEXUS_URL=$3
  curl -k -v -X 'PUT' \
  "${_NEXUS_URL}/service/rest/v1/security/realms/active" \
  -d '[ "NexusAuthenticatingRealm", "NexusAuthorizingRealm", "DockerToken" ]' \
  -u "$_NEXUS_USER:$_NEXUS_PWD" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json'
}

echo "Add Nexus service to insecure registries list"
oc patch image.config.openshift.io/cluster -p \
'{"spec":{"registrySources":{"insecureRegistries":["nexus-registry.ci-cd.svc.cluster.local"]}}}' --type='merge'
oc project ${CICD_PROJECT}
clear;echo "Setup Nexus..."
oc new-app sonatype/nexus3:${NEXUS_VERSION} --name=nexus -n ${CICD_PROJECT}
oc create route edge nexus --service=nexus --port=8081
oc rollout pause deployment nexus -n ${CICD_PROJECT}
oc set resources deployment nexus --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m -n ${CICD_PROJECT}
oc set volume deployment/nexus --remove --confirm -n ${CICD_PROJECT}
oc set volume deployment/nexus --add --overwrite --name=nexus-pv-1 \
--mount-path=/nexus-data/ --type persistentVolumeClaim \
--claim-name=nexus-pvc --claim-size=${NEXUS_PVC_SIZE} -n ${CICD_PROJECT}
oc set probe deployment/nexus --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok -n ${CICD_PROJECT}
oc set probe deployment/nexus --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/ -n ${CICD_PROJECT}
oc label deployment nexus app.kubernetes.io/part-of=Registry -n ${CICD_PROJECT}
oc rollout resume deployment nexus -n ${CICD_PROJECT}
sleep 60
oc wait --for=condition=Ready --timeout=300s pods -l deployment=nexus -n $CICD_PROJECT
clear;echo "Create Nexus repositories..."
NEXUS_POD=$(oc get pods -n $CICD_PROJECT | grep nexus |grep -v deploy |grep -v Termination| grep Running | awk '{print $1}')
oc cp $NEXUS_POD:/nexus-data/etc/nexus.properties nexus.properties
echo nexus.scripts.allowCreation=true >>  nexus.properties
oc cp nexus.properties $NEXUS_POD:/nexus-data/etc/nexus.properties
#rm -f nexus.properties
oc delete pod $NEXUS_POD
oc wait --for=condition=Ready --timeout=300s pods -l deployment=nexus -n $CICD_PROJECT
NEXUS_POD=$(oc get pods -n $CICD_PROJECT| grep nexus | grep -v deploy |grep Running| awk '{print $1}')
NEXUS_PASSWORD=$(oc exec -n $CICD_PROJECT $NEXUS_POD -- cat /nexus-data/admin.password)
CICD_NEXUS_PASSWORD=${NEXUS_PASSWORD}-$(date +%s)
NEXUS_URL=https://$(oc get route nexus --template='{{ .spec.host }}' -n $CICD_PROJECT)
add_nexus3_proxy_repo redhat-ga https://maven.repository.redhat.com/ga/ admin $NEXUS_PASSWORD $NEXUS_URL
add_nexus3_group_proxy_repo redhat-ga,maven-central,maven-releases,maven-snapshots maven-all-public admin $NEXUS_PASSWORD $NEXUS_URL
add_nexus3_docker_repo docker 5000 admin $NEXUS_PASSWORD $NEXUS_URL
add_nexus3_user admin $NEXUS_PASSWORD $NEXUS_URL $CICD_NEXUS_USER $CICD_NEXUS_PASSWORD
add_nexus3_npmproxy_repo npm https://registry.npmjs.org/ admin $NEXUS_PASSWORD $NEXUS_URL
add_nexus3_nugetproxy_repo nuget https://api.nuget.org/v3/index.json admin $NEXUS_PASSWORD $NEXUS_URL
config_nexus3_realms admin $NEXUS_PASSWORD $NEXUS_URL
echo "expose port 5000 for container registry"
oc expose deployment nexus --port=5000 --name=nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000
NEXUS_PASSWORD=$(oc exec $NEXUS_POD -- cat /nexus-data/admin.password)
CICD_NEXUS_PASSWORD_SECRET=$(echo ${CICD_NEXUS_PASSWORD}|base64)
END_BUILD=$(date +%s)
BUILD_TIME=$(expr ${END_BUILD} - ${START_BUILD})
echo ${NEXUS_PASSWORD} > nexus_password.txt
echo ${CICD_NEXUS_PASSWORD} >> nexus_password.txt
clear
echo "NEXUS URL = $(oc get route nexus -n ${CICD_PROJECT} -o jsonpath='{.spec.host}') "
echo "NEXUS Password = ${NEXUS_PASSWORD}"
echo "Nexus password is stored at bin/nexus_password.txt"
echo "Jenkins will use user/password store in secret nexus-credential to access nexus"
echo "Login to Nexus with admin and jenkins"
echo "Record this password and change it via web console"
echo "Start build pipeline and deploy to dev project by run start_build_pipeline.sh"
echo "Elasped time to build is $(expr ${BUILD_TIME} / 60 ) minutes"
