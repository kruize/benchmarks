# Clone the repo
git clone https://github.com/kusumachalasani/llm-rag-deployment.git

cd llm-rag-deployment/bootstrap-rag

# Pre-requisites
# Create the Imagestream that supports the demo
oc apply -f rhoai-rag-configuration/workbench-imagestream.yaml

# Install ODF and ceph-rbd-storage class. <TODO>
# This is required for llm PVC to support multiprocessing
# Has issues creating the storage system in AWS. 
# Workaround to use gp3 which is default Storage system

# Deploy the postres 

oc apply -f pgvector-rag-deployment/01-db-secret.yaml
oc apply -f pgvector-rag-deployment/02-pvc.yaml
oc apply -f pgvector-rag-deployment/03-deployment.yaml
oc apply -f pgvector-rag-deployment/04-services.yaml
oc apply -f pgvector-rag-deployment/05-grant-access-too-db.yaml

# Deploy the llm
oc apply -f shared-rag-llm/namespace.yaml

oc apply -f shared-rag-llm/pvc.yaml
oc apply -f shared-rag-llm/deployment.yaml
oc apply -f shared-rag-llm/service.yaml
oc apply -f shared-rag-llm/route.yaml


# Deploy gradio
oc apply -f gradio-rag/deployment.yaml
oc apply -f gradio-rag/service.yaml
oc apply -f gradio-rag/route.yaml

# Access gradio service
GRADIO_ROUTE=$(oc get route -n ic-shared-rag-llm  --template='{{range .items}}{{.spec.host}}{{"\n"}}{{end}}')
echo "Access gradio service as  ${GRADIO_ROUTE}"


# Extend pgvector and ingest data to DB 
oc apply -f pgvector-rag-deployment/06-extend-pg-db.yaml
oc apply -f pgvector-rag-deployment/07-ingest-data.yaml

 
