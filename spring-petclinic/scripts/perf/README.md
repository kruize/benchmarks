# Test with multiple instances 

`./scripts/perf/run_petclinic_openshift.sh -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-u JMETER_LOAD_USERS] [-d JMETER_LOAD_DURATION] [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-p PETCLINIC_IMAGE] [--cpureq=CPU_REQ] [--memreq MEM_REQ] [--cpulim=CPU_LIM] [--memlim MEM_LIM] [--env=ENV_VAR]` 

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
- **PETCLINIC_IMAGE**: Petclinic image to be used during deployment. It is optional, if not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be used for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit
- **ENV_VAR**: Environment variable

Example to test with multiple instances

**`$./scripts/perf/run-petclinic-openshift.sh -s rouging.os.fyre.ibm.com -e result -u 50 -d 10 -w 3 -m 2 -i 2 --iter=1 -r --cpulim=4 --cpureq=2 --memlim=1024M --memreq=512M`**

``` 
Instances , Throughput , Responsetime , MEM_MEAN , CPU_MEAN , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , CLUSTER_MEM% , CLUSTER_CPU% , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , WEB_ERRORS 
1 ,  1.5 , 13717 , 185.589 , 0.0654162 , .06008195908427761 , .07154538499852295 , 184 , 187 , 37.7179 , 21.2792 , 2 , 512M , 4 , 1024M , 0
2 ,  1.95 , 36022 , 401.126 , 0.116614 , .08914981041467199 , .14088270408803078 , 400 , 400 , 38.7379 , 21.9882 , 2 , 512M , 4 , 1024M , 0
Run , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , Throughput , Responsetime , WEB_ERRORS , CPU , CPU_MIN , CPU_MAX , MEM , MEM_MIN , MEM_MAX
0 , 2 , 512M , 4 , 1024M , 1.5 , 13723 , 0	,.0613606 , .06008195908427761 , .06174897795030225	, 184.267 , 184 , 184 
1 , 2 , 512M , 4 , 1024M , 1.5 , 13711 , 0	,.0694717 , .06882558557598842 , .07154538499852295	, 186.91 , 186 , 187 
0 , 2 , 512M , 4 , 1024M , 1.9 , 18414 , 0	,.1408827 , .14088270408803078 , .14088270408803078	, 400.887 , 400 , 400 
1 , 2 , 512M , 4 , 1024M , 2.0 , 17763 , 0	,.0923455 , .08914981041467199 , .094000952179322626	, 401.365 , 400 , 400 

```
Above image shows the log of the load run i.e, throghput, response time, total memory used by the pod, total cpu used by the pod, minimum cpu, maximum cpu, minimum memory, maximum memory, cluster memory usage in percentage,cluster cpu in percentage and web errors if any.

For CPU and Memory details refer Metrics-cpu.log and Metrics-mem.log . And for individual informations look into the logs generated during the run.

