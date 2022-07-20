#!/bin/sh
echo "Creating Projects ..."
CI_CD=ci-cd
DEV=dev
STAGE=stage
UAT=uat
PROD=prod
oc new-project $DEV  --display-name="Development Environment"
oc new-project $STAGE  --display-name="Staging Environment"
oc new-project $UAT --display-name="User Acceptance Test Environment"
oc new-project $PROD --display-name="Production Environment"
oc new-project $CI_CD  --display-name="CI/CD Tools"
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
