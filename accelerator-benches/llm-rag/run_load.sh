#!/bin/bash

if [ -z "$1" ]; then
  echo "Error: Provide namespace where gradio is deployed to run the load."
  exit 1
fi

NAMESPACE=$1
LOOP=10
BROWSERS=1
DURATION=600000
LOAD_TYPE="loop"
LOG_FILE="llm_rag_logs.txt"

# Delete the previous log file if exists
if [ -f "$log_file" ]; then
  rm "$log_file"
fi

# Access gradio service
GRADIO_ROUTE=$(oc get route -n ${NAMESPACE} --template='{{range .items}}{{.spec.host}}{{"\n"}}{{end}}' | grep "gradio")
GRADIO_URL=$(oc status -n ${NAMESPACE} | grep "gradio-route" | cut -d " " -f1)
echo "Accessing gradio service using ${GRADIO_URL}"

if [ ${LOAD_TYPE} == "loop" ]; then
	echo "Running the load with ${BROWSERS} browsers and ${LOOP} loops..."
	container_id=$(docker run -it --rm --network=host quay.io/kruizehub/llmragdemo-load-puppeteer:v1 node load.js --url ${GRADIO_URL} --loop ${LOOP} --browsers ${BROWSERS})

else
	echo "Running the load for 10mins... "
	# Run the load for a specific duration in ms
	container_id=$(docker run -d --rm --network=host quay.io/kruizehub/llmragdemo-load-puppeteer:v1 node load.js --url ${GRADIO_URL} --duration ${DURATION})

fi

podman logs --follow "$container_id" | while read line
do
  echo "$line" >> "$log_file"

  if [[ "$line" == *"Time taken to complete the load run:"* ]]; then
    cat ${log_file} | grep "Time taken"
    podman stop "$container_id"
    exit 1
  fi
done

