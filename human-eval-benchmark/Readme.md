# How to Run the LLM benchmark - Inference workload

## Pre-requisite 
As of now the user needs to have access to openshift AI cluster, create a Data Science project and setup a workbench with the following configuration 
Notebook Image: PyTorch
CUDA v12.1, Python v3.9, PyTorch v2.2
Container Size: small

## Load Script
Post setting up the workbench the user is required to upload the `script.ipynb` file on the jupyter notebook interface and start with following the cell instructions.

Towards the end of the script the user is prompted to fill the run duration, which is for how long the user wants to apply load or keep the model running, by default its set to 1hr (3600 sec). 



