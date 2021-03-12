# Test with multiple instances 

`./scripts/perf/run_galaxies_openshift.sh -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-u JMETER_LOAD_USERS] [-d JMETER_LOAD_DURATION] [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-g GALAXIES_IMAGE] [--cpureq=CPU_REQ] [--memreq MEM_REQ] [--cpulim=CPU_LIM] [--memlim MEM_LIM] [-t THREAD] [-R REQUEST_RATE] [-d DURATION] [--connection=CONNECTIONS] [--env=ENV_VAR]` 

- **BENCHMARK_SERVER_NAME** : Name of the cluster you are using
- **RESULTS_DIR_PATH** : Location where you want to store the results
- **JMETER_LOAD_USERS** : Number of users
- **JMETER_LOAD_DURATION** : Load duration
- **WARMUPS** : Number of warmups
- **MEASURES** : Number of measures

- **TOTAL_INST**: Number of instances
- **TOTAL_ITR**: Number of iterations you want to do the benchmarking
- **RE_DEPLOY**: true
- **NAMESPACE** : Namespace in which application to be deployed. It is optional, if not specified then `openshift-monitoring` will be considered as the namespace.
- **GALAXIES_IMAGE**: galaxies image to be used during deployment. It is optional, if not specified then the default image `dinogun/galaxies:1.2-jdk-11.0.10_9` will be used for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit
- **THREAD**: Number of threads
- **REQUEST_RATE**: Requests rate
- **DURATION**: Test duration
- **CONNECTIONS**: Number of connections
- **ENV_VAR**: Environment variable

Example to test with multiple instances

**`$./scripts/perf/run-galaxies-openshift.sh -s rouging.os.fyre.ibm.com -e result -u 10 -d 10 -w 1 -m 1 -i 1 --iter=1 -r `**

``` 
Instances , Throughput , Responsetime , MEM_MEAN , CPU_MEAN , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , CLUSTER_MEM% , CLUSTER_CPU% , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , WEB_ERRORS , RESPONSETIME_MAX , STDEV_RESPTIME_MAX
1 ,  585.023 , 622.883 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,  ,  ,  ,  , ,  , 619.44 ,  ,   
Run , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , Throughput , Responsetime , WEB_ERRORS , Responsetime_MAX , stdev_responsetime_max , CPU , CPU_MIN , CPU_MAX , MEM , MEM_MIN , MEM_MAX
0 ,  ,  ,  ,  , 858.80 , 444.16 , 122600 , 2.28 , 313.66	,0 , 0 , 0	, 0 , 0 , 0 
1 ,  ,  ,  ,  , 586.11 , 859.73 , 63260 , 4.60 , 619.44	,0 , 0 , 0	, 0 , 0 , 0 
2 ,  ,  ,  ,  , 310.16 , 564.76 , 35740 , 1.94 , 280.60	,0 , 0 , 0	, 0 , 0 , 0

```
Above image shows the log of the load run i.e, throghput, response time, total memory used by the pod, total cpu used by the pod, minimum cpu, maximum cpu, minimum memory, maximum memory, cluster memory usage in percentage, cluster cpu in percentage, web errors if any.

For CPU and Memory details refer Metrics-cpu.log and Metrics-mem.log . And for individual informations look into the logs generated during the run.

