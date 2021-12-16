#!/bin/sh
#
# Configure Nexus3 after installation
#
# Call this script with parameters:
#   $1: Nexus UserID
#   $2: Nexus Password
#   $3: Nexus URL
#   $4: Jenkins Password
#
# Add a NPM Proxy Repo to Nexus3
# add_nexus3_proxy_repo [repo-id] [repo-url] [nexus-username] [nexus-password] [nexus-url]
#

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

  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
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

  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
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

  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
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

  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_GROUP_ID/run"
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

  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
}

function add_nexus3_user() {
  set -x
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
  curl -v  -H "accept: application/json" -H "Content-Type: application/json" -d "$_USER_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/beta/security/users"
}
# Main body of the script
# $1: Nexus3 User ID
# $2: Nexus3 Password
# $3: Nexus3 URL
# $4: Jenkins User
# $5: Jenkins Password

# Red Hat Proxy Repos
add_nexus3_proxy_repo redhat-ga https://maven.repository.redhat.com/ga/ $1 $2 $3
#add_nexus3_proxy_repo jboss https://repository.jboss.org/nexus/content/groups/public/ $1 $2 $3

# Repo Group to include all proxy repos
#add_nexus3_group_proxy_repo redhat-ga,jboss,mvn-repository,maven-central,maven-releases,maven-snapshots maven-all-public $1 $2 $3
add_nexus3_group_proxy_repo redhat-ga,maven-central,maven-releases,maven-snapshots maven-all-public $1 $2 $3

# NPM Proxy Repo
add_nexus3_npmproxy_repo npm https://registry.npmjs.org/ $1 $2 $3

# Private Docker Registry
add_nexus3_docker_repo docker 5000 $1 $2 $3

# Maven release Repo
add_nexus3_release_repo releases $1 $2 $3

# Add Jenkins User
add_nexus3_user $1 $2 $3 $4 $5 