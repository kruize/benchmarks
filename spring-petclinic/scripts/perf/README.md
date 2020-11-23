# Test with multiple instances 

`./scripts/perf/run_petclinic_openshift.sh load_info perf_info` 

**load_info** : BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH JMETER_LOAD_USERS JMETER_LOAD_DURATION WARMUPS MEASURES

- **BENCHMARK_SERVER_NAME** : Name of the cluster you are using
- **NAMESPACE** : openshift-monitoring
- **RESULTS_DIR_PATH** : Location where you want to store the results
- **JMETER_LOAD_USERS** : Number of users
- **JMETER_LOAD_DURATION** : Load duration
- **WARMUPS** : Number of warmups
- **MEASURES** : Number of measures

**perf_info**: Redeploying the instances for different iterations for performance test
               (TOTAL_INST TOTAL_ITR RE_DEPLOY MANIFESTS_DIR)

- **TOTAL_INST**: Number of instances
- **TOTAL_ITR**: Number of iterations you want to do the benchmarking
- **RE_DEPLOY**: true
- **MANIFESTS_DIR**: Path where the manifest directory exists

Example to test with multiple instances

**`$./scripts/perf/run_petclinic_openshift.sh rouging.os.fyre.ibm.com openshift-monitoring result/ 300 60 5 3`**

``` 
Instances , Throughput , Responsetime , TOTAL_PODS_MEM , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , TOTAL_PODS_CPU , CLUSTER_MEM% , CLUSTER_CPU% , WEB_ERRORS 
1 ,  89.8 , 2351.5 , 476.676 , 0.382072 , 40.5538 , 24.535 , 0

```
Above image shows the log of the load run i.e, throghput, response time, total memory used by the pod, minimum cpu, maximum cpu, minimum memory, maximum memory, total cpu used by the pod, cluster memory usage in percentage,cluster cpu in percentage and web errors if any.

For CPU and Memory details refer Metrics-cpu.log and Metrics-mem.log . And for individual informations look into the logs generated during the run.

