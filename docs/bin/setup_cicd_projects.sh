#!/bin/sh
echo "Creating Projects ..."
CI_CD=ci-cd
DEV=dev
STAGE=stage
UAT=uat
PROD=prod
oc create ns $DEV  
oc create ns $STAGE  
oc create ns $UAT 
oc create ns $PROD 
oc create ns $CI_CD 
echo "Set $DEV,$STAGE,$UAT,$PROD to pull image from CI_CD"
oc policy add-role-to-group system:image-puller system:serviceaccounts:${DEV} -n ${CI_CD}
oc policy add-role-to-group system:image-puller system:serviceaccounts:${STAGE} -n ${CI_CD}
oc policy add-role-to-group system:image-puller system:serviceaccounts:${UAT} -n ${CI_CD}
oc policy add-role-to-group system:image-puller system:serviceaccounts:${PROD} -n ${CI_CD}

echo "Set ${CI_CD} to manage $DEV,$STAGE,$UAT,$PROD"
oc policy add-role-to-user edit system:serviceaccount:${CI_CD}:jenkins -n ${DEV}
oc policy add-role-to-user edit system:serviceaccount:${CI_CD}:jenkins -n ${STAGE}
oc policy add-role-to-user edit system:serviceaccount:${CI_CD}:jenkins -n ${UAT}
oc policy add-role-to-user edit system:serviceaccount:${CI_CD}:jenkins -n ${PROD}
