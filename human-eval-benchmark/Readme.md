# How to Run the LLM benchmark - Inference workload

The HumanEval workload is designed to evaluate the performance of language models on programming tasks.The HumanEval dataset consists of a collection of coding problems and their corresponding solutions. Each problem includes a description, input-output examples, and the expected code output.
The original HumanEval dataset can be found in the OpenAI [GitHub repository](https://github.com/openai/human-eval) with MIT license.The [HumanEval X](https://huggingface.co/datasets/THUDM/humaneval-x) with apache-2.0 license, and [HumanEval XL](https://huggingface.co/datasets/FloatAI/humaneval-xl) with apache-2.0 license, repository contains an extended version of the HumanEval dataset with additional problems and use cases.

There are two ways to run the Humaneval benchmark:

1. Workbench - Jupyter Notebook
2. Automated Job

## 1. Using the Workbench

As of now the user needs to have access to RedHat openshift AI cluster with atleast one GPU node and install the Nvidia GPU operator, create a Data Science project and setup a workbench with the following configuration
Notebook Image: PyTorch
CUDA v12.1, Python v3.9, PyTorch v2.2
Container Size: small

Post setting up the workbench the user is required to upload the `script_A.ipynb` and `script_B.ipynb` file on the jupyter notebook interface and start with following the cell instructions.

Towards the end of the script B the user is prompted to fill the run duration, which is for how long the user wants to apply load or keep the model running, by default its set to 1hr (3600 sec).

## 2. Automated Job

To run the benchmark in an automated way the user simply needs to login to the relevent Openshift AI cluster, create a namespace or you can use the default namespace. Set your desired environment variable in `job.yaml`, you have number of prompts or duration to choose from. If num_prompts and duration_in_seconds both are set num_prompts has a higher precedence. Apply `pvc.yaml` followed by applying `job.yaml`. This would deploy the humaneval benchamrk in the specified namespace.

The user can also make use of the `run_humaneval.sh` scrip with -n or -d option for number of prompts and duration_in_seconds respectively.
Example `./run_humaneval.sh <namespace name> -n 150` or `./run_humaneval.sh <namespace name> -d 800`

There is a cleanup script in the scripts folder which deletes the job and pvc, user needs to specify the namespace while running it.
`./cleanup.sh <namespace name>`
Example : `./cleanup.sh default`
