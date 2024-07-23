# How to Run the LLM benchmark - Inference workload

The HumanEval workload is designed to evaluate the performance of language models on programming tasks.The HumanEval dataset consists of a collection of coding problems and their corresponding solutions. Each problem includes a description, input-output examples, and the expected code output.
The original HumanEval dataset can be found in the OpenAI [GitHub repository](https://github.com/openai/human-eval) with MIT license.The [HumanEval X](https://huggingface.co/datasets/THUDM/humaneval-x) with apache-2.0 license, and [HumanEval XL](https://huggingface.co/datasets/FloatAI/humaneval-xl) with apache-2.0 license, repository contains an extended version of the HumanEval dataset with additional problems and use cases.

There are two ways to run the Humaneval benchmark:

1. Workbench - Jupyter Notebook
2. Automated Job

## 1. Using the Workbench 
## Pre-requisite 
As of now the user needs to have access to RedHat openshift AI cluster with atleast one GPU node and install the Nvidia GPU operator, create a Data Science project and setup a workbench with the following configuration 
Notebook Image: PyTorch
CUDA v12.1, Python v3.9, PyTorch v2.2
Container Size: small

## Load Script
Post setting up the workbench the user is required to upload the `script_A.ipynb` and `script_B.ipynb` file on the jupyter notebook interface and start with following the cell instructions.

Towards the end of the script B the user is prompted to fill the run duration, which is for how long the user wants to apply load or keep the model running, by default its set to 1hr (3600 sec). 

## 2. Automated Job 
In this approach we already have a combined script named `script.py`, and a Docker file which is used to create this docker image `quay.io/kruizehub/human-eval-deployment` which is used in the `job.yaml` file. 

The user simply needs to login to the relevent Openshift AI cluster and apply `pcv.yaml` followed by applying `job.yaml`. This would deploy the humaneval benchamrk in the specified namespace. 




