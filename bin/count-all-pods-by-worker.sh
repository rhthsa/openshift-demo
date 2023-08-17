#!/bin/bash
# oc get po -o wide --all-namespaces | grep ip-10-0-234-249.ap-southeast-1.compute.internal | wc -l
for node in $(oc get node -l node-role.kubernetes.io/worker="" --no-headers -o custom-columns='Name:.metadata.name')
do
   COUNT=$(oc get po -l app=backendW@ -o wide --all-namespaces | grep $node| wc -l)
   echo "$node => $COUNT pods"
done
