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

# Cleanup postigres 
oc delete -f pgvector-rag-deployment/01-db-secret.yaml
oc delete -f pgvector-rag-deployment/02-pvc.yaml
oc delete -f pgvector-rag-deployment/03-deployment.yaml
oc delete -f pgvector-rag-deployment/04-services.yaml

# Cleanup llm
oc delete -f shared-rag-llm/pvc.yaml
oc delete -f shared-rag-llm/deployment.yaml
oc delete -f shared-rag-llm/service.yaml
oc delete -f shared-rag-llm/route.yaml

# Cleanup gradio
oc delete -f gradio-rag/deployment.yaml
oc delete -f gradio-rag/service.yaml
oc delete -f gradio-rag/route.yaml

 
