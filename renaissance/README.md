
# About The Benchmark
The Renaissance Benchmark Suite aggregates common modern JVM workloads, including, but not limited to, Big Data, machine-learning, and functional programming. The suite is intended to be used to optimize just-in-time compilers, interpreters, GCs, and for tools such as profilers, debuggers, or static analyzers, and even different hardware. It is intended to be an open-source, collaborative project, in which the community can propose and improve benchmark workloads.

More information about this benchmark can be found on [Renaissance](https://github.com/renaissance-benchmarks/renaissance)
# Prerequisites
To generate the results from the Renaissance Benchmark,we need to:  

 - Install minikube(kubernetes cluster),which can be done from [Minikube](https://minikube.sigs.k8s.io/docs/start/) and then install prometheus on the minikube cluster. This can be done by following the steps in the [Autotune Installation](https://github.com/kruize/autotune/blob/master/docs/autotune_install.md). 

 You,also need to install a driver of your choice for running  renaissance onto your local system
 
 Download a driver (docker or podman)
 
 [Docker](https://docs.docker.com/engine/install/)
 
 [Podman](https://podman.io/getting-started/installation)
 
 # How To Run This Benchmark
 
 To run the benchmark on kubernetes cluster to collect performance metrics
 
 ./scripts/perf/renaissance-run.sh --clustertype=CLUSTER_TYPE -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-g RENAISSANCE_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] [-b BENCHMARKS] [-R REPETITIONS] [-d DURATION] "
 
 - **CLUSTER_TYPE**: Type of cluster. Supports openshift , minikube.
- **BENCHMARK_SERVER**: Name of the cluster you are using
- **RESULTS_DIR_PATH**: Directory to store results
- **DURATION**: Duration of each warmup and measurement run.
- **WARMUPS**: No.of warmup runs.
- **MEASURES**: No.of measurement runs.
- **ITERATIONS**: No.of iterations.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit
- **RENAISSANCE_IMAGE**:prakalp23/renaissance1041:latest 
- **BENCHMARKS**:Choice of a microbenchmark from Renaissance [Microbenchmarks](https://github.com/renaissance-benchmarks/renaissance)

Example:./renaissance-run.sh --clustertype=minikube -s localhost -e ./results -w 1 -m 1 -i 1 --iter=1 -r -n default  --cpureq=1.5 --memreq=3152M --cpulim=1.5 --memlim=3152M -b "page-rank" -g prakalp23/renaissance1041:latest -d 60

 # The Experiment Results
 
 The experiment results using the above scripts generates a csv file which contains the resource usage information for the Renaissance Benchmark can be found here
 
 [Renaissance Results](https://github.com/Prakalp23/autotune-results/tree/renaissance/Renaissance)
 
 
## Scripts Details

| Script Name                   |       What it does?																			|
|-------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| perf/getmetrics-promql.sh     |       Has prometheus queries that are required calculate the metrics required for objective function and the benchmark.                                       	|
| perf/parsemetrics-promql.sh   |       Parse the prometheus metrics data to calculate the average , max and min values as per the requirement of the benchmark.                                	|
| perf/ci.php			|	Use to measure confidence interval of data.															|
| perf/parsemetrics-wrk.sh      |       Parse the metrics data from hyperfoil/wrk load simulator.                                                                                               	|


 
