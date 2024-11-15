#!/bin/bash

if [ -z "$1" ]; then
  echo "Error: Provide namespace to uninstall the job."
  exit 1
fi

NAMESPACE=$1
PVC_NAME="training-ttm-pvc"

kubectl delete -f training-ttm -n $NAMESPACE
kubectl delete -f training-ttm-1024 -n $NAMESPACE
kubectl delete -f pvc.yaml -n $NAMESPACE
