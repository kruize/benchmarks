# Test with multiple instances 

`./scripts/perf/run_petclinic_openshift.sh -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-u JMETER_LOAD_USERS] [-d JMETER_LOAD_DURATION] [-a WARMUPS] [-m MEASURES] [-i TOTAL_INST] [-l TOTAL_ITR] [-r= set redeploy to true] [-p PETCLINIC_IMAGE] [--cpureq=CPU_REQ] [--memreq MEM_REQ] [--cpulim=CPU_LIM] [--memlim MEM_LIM]` 

- **BENCHMARK_SERVER_NAME** : Name of the cluster you are using
- **RESULTS_DIR_PATH** : Location where you want to store the results
- **JMETER_LOAD_USERS** : Number of users
- **JMETER_LOAD_DURATION** : Load duration
- **WARMUPS** : Number of warmups
- **MEASURES** : Number of measures

- **TOTAL_INST**: Number of instances
- **TOTAL_ITR**: Number of iterations you want to do the benchmarking
- **RE_DEPLOY**: true
- **PETCLINIC_IMAGE**: Petclinic image to be used during deployment. It is optional, if not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be used for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit

Example to test with multiple instances

**`$./scripts/perf/run-petclinic-openshift.sh -s rouging.os.fyre.ibm.com -e result/ -u 150 -d 40 -a 3 -m 2 -i 2 -l 2 -r`**

``` 
Instances , Throughput , Responsetime , TOTAL_PODS_MEM , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , TOTAL_PODS_CPU , CLUSTER_MEM% , CLUSTER_CPU% , WEB_ERRORS 
1 ,  89.8 , 2351.5 , 476.676 , 0.382072 , 40.5538 , 24.535 , 0

```
Above image shows the log of the load run i.e, throghput, response time, total memory used by the pod, minimum cpu, maximum cpu, minimum memory, maximum memory, total cpu used by the pod, cluster memory usage in percentage,cluster cpu in percentage and web errors if any.

For CPU and Memory details refer Metrics-cpu.log and Metrics-mem.log . And for individual informations look into the logs generated during the run.

