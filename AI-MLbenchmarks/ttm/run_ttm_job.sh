#!/bin/bash

JOB_YAML=$1
JOB_NAME=$2
NAMESPACE=$3
PVC_NAME="training-ttm-pvc"

# Function to check if the job is completed
check_job_status() {
  kubectl -n $NAMESPACE get job $JOB_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status} {.status.conditions[?(@.type=="Failed")].status}'
 # 2>/dev/null
}

# Check if the PVC exists
kubectl -n $NAMESPACE get pvc $PVC_NAME > /dev/null 2>&1

# If PVC does not exist, apply the PVC YAML file
if [ $? -ne 0 ]; then
  echo "PVC $PVC_NAME does not exist. Applying PVC..."
  kubectl apply -f pvc.yaml -n $NAMESPACE
else
  echo "PVC $PVC_NAME already exists. Skipping creation."
fi

echo "Creating Kubernetes job from $JOB_YAML..."
#kubectl apply -f $JOB_YAML -n $NAMESPACE
echo "Job created: $JOB_NAME"

# Wait for the job to complete
echo "Waiting for the job to complete..."

while true; do
  JOB_STATUS=$(check_job_status)
#  echo "JOB_STATUS $JOB_STATUS"
  if [ "$JOB_STATUS" == "True " ]; then
    echo "Job $JOB_NAME completed successfully!"
    break
  else
    #echo "Job $JOB_NAME is still running... Checking again in 10 seconds."
    sleep 10
  fi
done

# Get the pod name associated with the job
POD_NAME=$(kubectl -n $NAMESPACE get pods --selector=job-name=$JOB_NAME --output=jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo "Failed to retrieve the pod name for job $JOB_NAME"
    exit 1
fi

echo "Job pod: $POD_NAME"

# Collect the logs from the pod
LOG_FILE="${JOB_NAME}_logs.txt"
kubectl logs $POD_NAME -n $NAMESPACE > $LOG_FILE

if [ $? -eq 0 ]; then
    echo "Logs collected in $LOG_FILE"
else
    echo "Failed to collect logs from pod $POD_NAME"
fi

# Extract the last lines (weather and electricity)
tail -n 7 $LOG_FILE | awk '
{
#  print "Row being processed: " $0
  if (NR == 2) {
    print "Weather Times: fs5_total_train_time: "$2", fs10_total_train_time: "$4
  }
  else if (NR == 3) {
    print "Electricity Times: fs5_total_train_time: "$2", fs10_total_train_time: "$4
  }
}'

kubectl delete -f $JOB_YAML -n $NAMESPACE
kubectl delete -f pvc.yaml -n $NAMESPACE

