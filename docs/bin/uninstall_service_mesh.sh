#!/bin/bash
for project in $(oc get smcp --all-namespaces --no-headers|awk '{print $1}')
do
    oc delete smmr -n $project default
    oc delete smcp  $(oc get smcp -n $project -oname) -n $project 
   
done 
oc delete validatingwebhookconfiguration/openshift-operators.servicemesh-resources.maistra.io
oc delete mutatingwebhookconfigura$tions/openshift-operators.servicemesh-resources.maistra.io
oc delete svc maistra-admission-controller -n openshift-operators
oc delete -n openshift-operators $(oc get daemonset -n openshift-operators -oname | grep istio)
oc delete clusterrole/istio-admin clusterrole/istio-cni clusterrolebinding/istio-cni
oc delete clusterrole istio-view istio-edit
oc get crds -o name | grep '.*\.istio\.io' | xargs -r -n 1 oc delete
oc get crds -o name | grep '.*\.maistra\.io' | xargs -r -n 1 oc delete
oc delete secret -n openshift-operators maistra-operator-serving-cert
oc delete cm -n openshift-operators maistra-operator-cabundl
