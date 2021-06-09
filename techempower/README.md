# Instructions to run the techempower Framework (Quarkus) application using scripts 
**The scripts written supports**
- [Openshift](#Openshift)

Pre-requisites: javac and git 

tfb-qrh represents TechEmpower Framework benchmark - Quarkus resteasy - hibernate.

Example to deploy and run multiple tfb-qrh application instances using default image

```
## Openshift
To deploy the benchmark use `tfb-qrh-deploy-openshift.sh`

`./scripts/tfb-qrh-deploy-openshift.sh -s BENCHMARK_SERVER [-i SERVER_INSTANCES] [-n NAMESPACE] [-g TFB_IMAGE] [--cpureq=CPU_REQ] [--memreq MEM_REQ] [--cpulim=CPU_LIM] [--memlim MEM_LIM]`

- **BENCHMARK_SERVER**: Name of the cluster you are using
- **SERVER_INSTANCES**: Number of tfb-qrh instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **NAMESPACE**: Namespace in which tfb-qrh application is to be deployed. It is optional, if not specified then `default` will be considered as the namespace. 
- **TFB_IMAGE**: TechEmpower Framework Quarkus image to deploy. It is optional, if is not specified then the default image `kruize/tfb-qrh:1.13.2.F_mm.v1` will be considered for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit

To deploy and run the load with tfb application on openshift cluster to collect performance metrics

`./scripts/perf/run-tfb-qrh-openshift.sh -s BENCHMARK_SERVER -e RESULTS_DIR [-i SERVER_INSTANCES] [-n NAMESPACE] [-g TFB_IMAGE] [-d DURATION] [-w WARMUPS] [-m MEASURES] [--iter ITERATIONS] [-t THREADS] [-R RATE] [--connection CONNECTIONS] [-r RE_DEPLOY] [--cpureq=CPU_REQ] [--memreq MEM_REQ] [--cpulim=CPU_LIM] [--memlim MEM_LIM] `

- **BENCHMARK_SERVER**: Name of the cluster you are using
- **RESULTS_DIR**: Directory to store results
- **SERVER_INSTANCES**: Number of tfb-qrh instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **NAMESPACE**: Namespace in which tfb-qrh application is to be deployed. It is optional, if not specified then `default` will be considered as the namespace.
- **TFB_IMAGE**: TechEmpower Framework Quarkus image to deploy. It is optional, if is not specified then the default image `kruize/tfb-qrh:1.13.2.F_mm.v1` will be considered for the deployment.
- **RE_DEPLOY**: Deploy the application in cluster. If application is already running, it deletes the old deployment and deploy again.
- **DURATION**: Duration of each warmup and measurement run.
- **WARMUPS**: No.of warmup runs.
- **MEASURES**: No.of measurement runs.
- **ITERATIONS**: No.of iterations.
- **THREADS**: No.of threads used by hyperfoil/wrk2 client
- **RATE**: Rate of transaction used by hyperfoil/wrk2
- **CONNECTION**: No.of connections used by hyperffoil/wrk2
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit

Example:
`./scripts/perf/run-tfb-qrh-openshift.sh -s example.com -e results -i 1 -n default -d 30 -w 5 -m 3 --iter=3 -t 3 -R 100 --connection=100 -r`

# Cleanup
`$ ./scripts/tfb-cleanup.sh -c CLUSTER_TYPE[openshift] [-n NAMESPACE]`
- **CLUSTER_TYPE**: openshift
- **NAMESPACE**: Namespace in which techempower framework quarkus application is deployed.

