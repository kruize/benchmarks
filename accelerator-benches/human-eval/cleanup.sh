#!/bin/bash

JOB_NAME=human-eval-deployment-job
PVC_NAME=human-eval-pvc
JOB_YAML=./manifests/job.yaml
PVC_YAML=./manifests/pvc.yaml

if [ -z "$1" ]; then
  echo "Error: Provide namespace to uninstall the job."
  exit 1
fi

NAMESPACE=$1

# reset the job yaml
cp ${JOB_YAML}.bak $JOB_YAML

# reset pvc yaml
cp ${PVC_YAML}.bak $PVC_YAML

#  delete job
oc delete job $JOB_NAME -n "$NAMESPACE"

#  delete pvc
oc delete pvc $PVC_NAME -n "$NAMESPACE"