#!/bin/bash
function check_operator(){
   STATUS=""
   while [ "$STATUS" != "Succeeded" ];
   do 
      STATUS=$(oc get csv/$1 -n default -o jsonpath='{.status.phase}')
      echo "$1 phase: $STATUS"
      if [ "$STATUS" != "Succeeded" ];
      then 
         echo "wait for 15 sec..."
         sleep 15
      fi
   done
}

# oc project rhacs-operator 1>/dev/null 2>&1
# if [ $? -ne 0 ]; then
#     oc new-project rhacs-operator
# fi
# echo "Check ACS operators"
# ACS_OPERATOR=$(oc get ClusterServiceVersion -n default| grep rhacs-operator | awk '{print $1}')
# if [ "$OSSM_OPERATOR" = "" ];
# then
#    echo "Install ACS operator"
#    oc apply -f manifests/acs-sub.yaml
# fi

# oc apply -f config/kiali-operator.yaml
# sleep 30
# check_operator $(oc get csv -n default | grep kiali | awk '{print $1}')
# check_operator $(oc get csv -n default | grep jaeger | awk '{print $1}')
# check_operator $(oc get csv -n default | grep servicemeshoperator | awk '{print $1}')
# oc wait --for condition=established --timeout=180s \
# crd/servicemeshcontrolplanes.maistra.io \
# crd/servicemeshmemberrolls.maistra.io \
# crd/servicemeshmembers.maistra.io \
# crd/kialis.kiali.io \
# crd/jaegers.jaegertracing.io
echo "Create Stackrox Namespace"
oc new-project stackrox 1>/dev/null 2>&1
echo "Create Central"
oc create -f manifests/acs-central.yaml -n stackrox
echo "Wait for Scanner initialization...."
oc wait --for condition=Ready --timeout=180s pods -l app=scanner -n stackrox 1>/dev/null 2>&1
echo "Scanner is started"
echo "Wait for Central initialization...."
oc wait --for condition=Ready --timeout=180s pods -l app=central -n stackrox 1>/dev/null 2>&1
echo "Central is started"
oc get pods -n stackrox
sleep 5
ROX_URL=https://$(oc get route central -n stackrox -o jsonpath='{.spec.host}')
ROX_CENTRAL_ADDRESS=$(oc get route central -n stackrox -o jsonpath='{.spec.host}'):443
ROX_PASSWORD=$(oc get secret central-htpasswd -n stackrox -o jsonpath='{.data.password}'|base64 -d)