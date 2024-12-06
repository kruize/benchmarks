#!/bin/bash

JOB_YAML=./manifests/job.yaml
JOB_NAME=human-eval-deployment-job
NAMESPACE=${1:-default}
PVC_NAME="human-eval-pvc"

DEFAULT_NUM_PROMPTS=500
DEFAULT_DURATION_IN_SECONDS=1800

# job status function
check_job_status() {
  oc get job $JOB_NAME -n $NAMESPACE -o jsonpath='{.status.succeeded}'
}

# check if pvc is present
oc get pvc $PVC_NAME -n $NAMESPACE  > /dev/null 2>&1

# apply pvc if not there
if [ $? -ne 0 ]; then
  echo "PVC $PVC_NAME does not exist. Applying PVC..."
  oc apply -f ./manifests/pvc.yaml -n $NAMESPACE
else
  echo "PVC $PVC_NAME already exists. Skipping creation."
fi


cp $JOB_YAML ${JOB_YAML}.bak

# Parse command-line options
while getopts "n:d:" opt; do
  case $opt in
    n)
      NUM_PROMPTS="$OPTARG"
      ;;
    d)
      DURATION_IN_SECONDS="$OPTARG"
      ;;
    *)
      echo "Usage: $0 [-n num_prompts] [-d duration_in_seconds]"
      exit 1
      ;;
  esac
done

echo $NAMESPACE
if [ "$NAMESPACE" != "default" ]; then
  echo "Updating namespace in YAML..."
  sed -i "s/namespace: default/namespace: $NAMESPACE/" $JOB_YAML
fi

# Update the Job YAML
if [ -n "$NUM_PROMPTS" -a "$NUM_PROMPTS" != "$DEFAULT_NUM_PROMPTS" ]; then
  sed -i "/- name: num_prompts/c\            - name: num_prompts\n              value: \"$NUM_PROMPTS\"" $JOB_YAML
  sed -i "/value: '500'/d" $JOB_YAML
  sed -i '/- name: duration_in_seconds/,+1d' $JOB_YAML
elif [ -n "$DURATION_IN_SECONDS" -a "$DURATION_IN_SECONDS" != "$DEFAULT_DURATION_IN_SECONDS"]; then
  sed -i "/- name: duration_in_seconds/c\            - name: duration_in_seconds\n              value: \"$DURATION_IN_SECONDS\"" $JOB_YAML
  sed -i "/value: '1800'/d" $JOB_YAML
  sed -i '/- name: num_prompts/,+1d' $JOB_YAML
fi
echo "Generated YAML file: $JOB_YAML"

#  apply job
echo "Creating Kubernetes job from $JOB_YAML..."
oc apply -f $JOB_YAML -n $NAMESPACE
echo "Job created: $JOB_NAME"
echo "Waiting for the job to complete..."


while true; do
  JOB_STATUS=$(check_job_status)
  echo "JOB_STATUS $JOB_STATUS"
  if [ "$JOB_STATUS " == "1 " ]; then
    echo "Job $JOB_NAME completed successfully!"
    break
  else
    echo "Job $JOB_NAME is still running... Checking again in 60 seconds."
    sleep 60
  fi
done

# Get the pod name associated with the job
POD_NAME=$(oc -n $NAMESPACE get pods --selector=job-name=$JOB_NAME --output=jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo "Failed to retrieve the pod name for job $JOB_NAME"
    exit 1
fi

echo "Job pod: $POD_NAME"

# Collect the logs from the pod
LOG_FILE="${JOB_NAME}_logs.txt"
oc logs $POD_NAME -n $NAMESPACE > $LOG_FILE

if [ $? -eq 0 ]; then
    echo "Logs collected in $LOG_FILE"
else
    echo "Failed to collect logs from pod $POD_NAME"
fi

# Extract the last line having prompts and duration details
tail -n 1 "$LOG_FILE"


