#!/bin/bash

JOB_YAML=./manifests/job.yaml
JOB_NAME=human-eval-deployment-job
NAMESPACE=default
PVC_NAME="human-eval-pvc"

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

# Prompt user for input
echo "Choose one of the following options:"
echo "1. Enter num_prompts"
echo "2. Enter duration_in_seconds"
read -p "Enter your choice (1 or 2): " CHOICE

# Initialize variables for user input
NUM_PROMPTS=""
DURATION_IN_SECONDS=""

# Get user input based on choice
if [ "$CHOICE" == "1" ]; then
  read -p "Enter num_prompts: " NUM_PROMPTS
elif [ "$CHOICE" == "2" ]; then
  read -p "Enter duration_in_seconds: " DURATION_IN_SECONDS
else
  echo "Invalid choice. Exiting."
  exit 1
fi

cp $JOB_YAML ${JOB_YAML}.bak

# Update the Job YAML
if [ -n "$NUM_PROMPTS" ]; then
  sed -i "/- name: num_prompts/c\            - name: num_prompts\n              value: \"$NUM_PROMPTS\"" $JOB_YAML
  sed -i "/- name: duration_in_seconds/d" $JOB_YAML
elif [ -n "$DURATION_IN_SECONDS" ]; then
  sed -i "/- name: duration_in_seconds/c\            - name: duration_in_seconds\n              value: \"$DURATION_IN_SECONDS\"" $JOB_YAML
  sed -i "/- name: num_prompts/d" $JOB_YAML
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

cp ${JOB_YAML}.bak $JOB_YAML

oc delete job $JOB_NAME -n $NAMESPACE
oc delete pvc $PVC_NAME -n $NAMESPACE
