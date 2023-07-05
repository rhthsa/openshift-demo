#!/bin/bash
LABEL="app=backend,version=v1"
ZONE_LABEL="zone"
for node in $(oc get node -l node-role.kubernetes.io/worker="" --no-headers -o custom-columns='Name:.metadata.name')
do
   ZONE=$(oc get node $node -o jsonpath='{.metadata.labels.'$ZONE_LABEL'}')
   COUNT=$(oc get po -l "${LABEL}" -o custom-columns='Node:.spec.nodeName'|grep $node|wc -l|awk '$1=$1')
   echo "$node ($ZONE) => $COUNT"
done