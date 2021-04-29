#!/bin/bash
CONTROL_PLANE=$1
DONE=1
while [ $DONE -ne 0 ];
do
  sleep 5
  clear
  oc get smcp -n $CONTROL_PLANE
  echo
  echo
  CURRENT_STATUS=$(oc get smcp basic-install -n $CONTROL_PLANE -o jsonpath='{.status.annotations.readyComponentCount}')
  printf "Ready Component Count: %s\n" "$CURRENT_STATUS"
  READY=$(echo $CURRENT_STATUS|awk -F'/' '{print $1}')
  TOTAL=$(echo $CURRENT_STATUS|awk -F'/' '{print $2}')
  if [ $READY -gt 0 ];
  then
    printf "Ready: \n"
    for i in $(oc get smcp basic-install -n $CONTROL_PLANE -o jsonpath='{.status.readiness.components.ready[*]}')
    do
      printf "=> %s\n" "$i"
    done
  fi
  if [ $READY -eq  $TOTAL ];
  then
    DONE=0
  fi
done
echo
oc get pods -n $CONTROL_PLANE