# Clone the repo
git clone https://github.com/kusumachalasani/llm-rag-deployment.git -b kruize-ai

cd llm-rag-deployment/

## Update the namespace from `ic-shared-rag-llm` to `kruize-hackathon`
NAMESPACE="kruize-hackathon"
# Update namespace in `examples/pipelines/data_ingest.py` which is used to ingest data
sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" examples/pipelines/data_ingest.py

cd bootstrap-rag

## Update namespace for all yamls
find ./pgvector-rag-deployment -type f -exec sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" {} +
find ./shared-rag-llm -type f -exec sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" {} +
find ./gradio-rag -type f -exec sed -i "s/ic-shared-rag-llm/${NAMESPACE}/g" {} +

# Pre-requisites
# Create the Imagestream that supports the demo to start workbench
#oc apply -f rhoai-rag-configuration/workbench-imagestream.yaml

# Install ODF and ceph-rbd-storage class. <TODO>
# This is required for llm PVC to support multiprocessing
# Has issues creating the storage system in AWS. 
# Workaround to use gp3 which is default Storage system

# Deploy the postigres 

oc apply -f pgvector-rag-deployment/01-db-secret.yaml
oc apply -f pgvector-rag-deployment/02-pvc.yaml
oc apply -f pgvector-rag-deployment/03-deployment.yaml
oc apply -f pgvector-rag-deployment/04-services.yaml
oc apply -f pgvector-rag-deployment/05-grant-access-to-db.yaml

# Deploy the llm
#oc apply -f shared-rag-llm/namespace.yaml

oc apply -f shared-rag-llm/pvc.yaml
oc apply -f shared-rag-llm/deployment.yaml
oc apply -f shared-rag-llm/service.yaml
oc apply -f shared-rag-llm/route.yaml


# Deploy gradio
oc apply -f gradio-rag/deployment.yaml
oc apply -f gradio-rag/service.yaml
oc apply -f gradio-rag/route.yaml

# Access gradio service
GRADIO_ROUTE=$(oc get route -n ${NAMESPACE} --template='{{range .items}}{{.spec.host}}{{"\n"}}{{end}}')
echo "Access gradio service as  ${GRADIO_ROUTE}"

#Update the namespace 
# Extend pgvector and ingest data to DB 
oc apply -f pgvector-rag-deployment/06-extend-pg-db.yaml
oc apply -f pgvector-rag-deployment/07-ingest-data.yaml

 
