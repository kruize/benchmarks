#!/bin/bash

if [ -z "$1" ]; then
  echo "Error: Provide namespace to deploy the application."
  exit 1
fi

NAMESPACE=$1

# Clone the repo
git clone https://github.com/kusumachalasani/llm-rag-deployment.git -b kruize-ai

cd llm-rag-deployment/

# Update the namespace from `ic-shared-rag-llm` to given namespace
# Update namespace in `examples/pipelines/data_ingest.py` which is used to ingest data
sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" examples/pipelines/data_ingest.py

cd bootstrap-rag
## Update namespace for all yamls
find ./pgvector-rag-deployment -type f -exec sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" {} +
find ./shared-rag-llm -type f -exec sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" {} +
find ./gradio-rag -type f -exec sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" {} +

# Cleanup jobs
oc delete -f pgvector-rag-deployment/06-extend-pg-db.yaml
oc delete -f pgvector-rag-deployment/07-ingest-data.yaml

# Cleanup postgres 
oc delete -f pgvector-rag-deployment/03-deployment.yaml
oc delete -f pgvector-rag-deployment/04-services.yaml
oc delete -f pgvector-rag-deployment/02-pvc.yaml
oc delete -f pgvector-rag-deployment/01-db-secret.yaml

# Cleanup llm
oc delete -f shared-rag-llm/deployment.yaml
oc delete -f shared-rag-llm/service.yaml
oc delete -f shared-rag-llm/route.yaml
oc delete -f shared-rag-llm/pvc.yaml

# Cleanup gradio
oc delete -f gradio-rag/deployment.yaml
oc delete -f gradio-rag/service.yaml
oc delete -f gradio-rag/route.yaml

