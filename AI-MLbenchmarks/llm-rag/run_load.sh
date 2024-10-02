#!/bin/bash

if [ -z "$1" ]; then
  echo "Error: Provide namespace where gradio is deployed to run the load."
  exit 1
fi

NAMESPACE=$1

# Access gradio service
GRADIO_ROUTE=$(oc get route -n ${NAMESPACE} --template='{{range .items}}{{.spec.host}}{{"\n"}}{{end}}' | grep "gradio")
echo "Access gradio service as  ${GRADIO_ROUTE}"

# Run the load with default parameters [ Runs the 8 questions once with 1 browser ]
#docker run -d --rm --network=host quay.io/kruizehub/llmragdemo-load-puppeteer:v1 node load.js --url ${GRADIO_ROUTE}

# Run the load by looping over questions with 1 browser
docker run -d --rm --network=host quay.io/kruizehub/llmragdemo-load-puppeteer:v1 node load.js --url ${GRADIO_ROUTE} --loop 15

# Run the load by looping over questions with 2 browers
#docker run -d --rm --network=host quay.io/kruizehub/llmragdemo-load-puppeteer:v1 node load.js --url ${GRADIO_ROUTE} --loop 15 --browsers 2

# Run the load for a specific duration ( 10 mins )
#docker run -d --rm --network=host quay.io/kruizehub/llmragdemo-load-puppeteer:v1 node load.js --url ${GRADIO_ROUTE} --duration 600000
