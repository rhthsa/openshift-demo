#!/bin/sh
PROJECT=ci-cd
PIPELINE=backend-release-uat-pipeline
OUTPUT=$(oc start-build ${PIPELINE} -n ${PROJECT})
BUILD=$(echo ${OUTPUT}|awk '{print $1}'|awk -F'/' '{print $2}')
echo "Build ${BUILD} started"
echo "Wait 5 sec for ${BUILD} to be started"
sleep 5
oc logs build/${BUILD} -n ci-cd
