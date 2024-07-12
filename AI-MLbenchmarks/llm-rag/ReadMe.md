## LLM+RAG Workload

### Deploy the LLM+RAG Demo

To deploy the demo, run the following command:

```sh
./deploy.sh
```

This script performs the following actions:
- Clone the repo `https://github.com/kusumachalasani/llm-rag-deployment.git`.
- Uses namespace `ic-shared-rag-llm` for the demo.
- Includes a custom GenAI image.
- Deploys the Postgres database.
- Deploys the LLM which uses model MaziyarPanahi/Mistral-7B-Instruct-v0.2
- Deploys the Gradio service for Q&A.
- Ingests several sources of data into the database for RAG (Retrieval-Augmented Generation).

### Running the Load

``` 
docker run -d --rm --network=host quay.io/kusumach/llmragdemo-load-puppeteer:v1 node load.js --url <GRADIO_Service> [--duration <Duration load runs in ms>:default null] [--delay <Delay between questions in ms>:default 10] [--browsers <Number of browsers running the load in parallel>:default 1]

```

