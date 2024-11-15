FROM python:3.9

# Install git to clone the repository
RUN apt-get update && apt-get install -y git

# Clone the benchmark repo
RUN git clone https://github.com/ibm-granite/granite-tsfm.git

# Set the working directory
WORKDIR /granite-tsfm

# Install dependencies including optional ones for notebooks
RUN pip install .[notebooks]

# Copy training script and datasets to the container
COPY ttm_benchmarking_512_96.py /granite-tsfm/
COPY ttm_benchmarking_1024_96.py /granite-tsfm/
COPY datasets /granite-tsfm/datasets/

# Create output directory with correct permissions
RUN mkdir -p /granite-tsfm/ttm_results_benchmark_512_96 && chmod -R 777 /granite-tsfm/ttm_results_benchmark_512_96
RUN mkdir -p /granite-tsfm/ttm_results_benchmark_1024_96 && chmod -R 777 /granite-tsfm/ttm_results_benchmark_1024_96

# Set the entry point to run the training script
ENTRYPOINT ["python3"]

