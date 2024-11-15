# TTM BENCHMARK

## Run ttm-benchmark as job

- Runs the ttm benchmark for both 512 and 1024 context lengths for weather and electricity datasets sequentially for a given namespace.
- Command to run
	- `./run_ttm.sh <NAMESPACE>`
	- Example:  `./run-ttm.sh default`


## Run ttm-benchmark using workbench

- Create a workbench with notebook image `Standard Data Science` with `Small` Container size with an accelerate profile.
- Clone Repo: https://github.com/ibm-granite/granite-tsfm.git
- Download Data set from : https://drive.google.com/drive/folders/1ohGYWWohJlOlb2gsGTeEq3Wii2egnEPR?usp=sharing
	- Upload the two csv’s as : 
		- Create folder `datasets/weather` and `datasets/electricity` in notebooks/hfdemo/tinytimemixer
		- Upload WTH.csv as weather.csv in datasets/weather
		- Upload ECL.csv as electricity.csv in datasets/electricity

### To run the benchmark: 
- Open a terminal window and run `pip install .[notebooks]`
- Go to https://github.com/IBM/tsfm/blob/main/notebooks/hfdemo/tinytimemixer
- Update `list_datasets` to use only "weather", "electricity" in both `ttm_benchmarking_512_96.ipynb` and `ttm_benchmarking_1024_96.ipynb`
- Run the ipynb scripts for benchmarking.

## Attributions

This project uses the following resources:

1. **[ibm-granite](https://github.com/ibm-granite/granite-tsfm.git)** - Used Jupyter notebook images, which were then converted into Kubernetes jobs and executed.
