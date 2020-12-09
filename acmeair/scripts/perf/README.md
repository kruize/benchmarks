# Test with multiple instances 

`./scripts/perf/run_acmeair_openshift.sh  -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-u JMETER_LOAD_USERS] [-d JMETER_LOAD_DURATION] [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-a ACMEAIR_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM]` 

- **BENCHMARK_SERVER_NAME** : Name of the cluster you are using
- **RESULTS_DIR_PATH** : Location where you want to store the results
- **JMETER_LOAD_USERS** : Number of users
- **JMETER_LOAD_DURATION** : Load duration
- **WARMUPS** : Number of warmups
- **MEASURES** : Number of measures

- **TOTAL_INST**: Number of instances
- **TOTAL_ITR**: Number of iterations you want to do the benchmarking
- **RE_DEPLOY**: true
- **NAMESPACE** : Namespace in which application to be deployed. It is optional, if not specified then `default` will be considered as the namespace.
- **PETCLINIC_IMAGE**: Petclinic image to be used during deployment. It is optional, if not specified then the default image `dinogun/acmeair-monolithic` will be used for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit

Example to test with multiple instances

**`$./scripts/perf/run_acmeair_openshift.sh -s rouging.os.fyre.ibm.com -e result -u 50 -d 20 -w 3 -m 2 -i 2 --iter=1 -r --cpureq=2 --cpulim=4 --memreq=512M --memlim=1024M`**

``` 
Instances , Throughput , Responsetime , TOTAL_PODS_MEM , TOTAL_PODS_CPU , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , CLUSTER_MEM% , CLUSTER_CPU% , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , WEB_ERRORS 
1 ,  21.1 , 425.5 , 212.393 , 0.262048 , .230064171307710832 , .30134062341363525 , 208 , 218 , 38.1385 , 22.4753 , 2 , 512M ,4 , 1024M , 0
2 ,  29.1 , 1042.5 , 372.714 , 0.36786 , .345283521075791429 , .3950907877269441885 , 368 , 372 , 38.9108 , 21.3539 , 2 , 512M ,4 , 1024M , 0
Run , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , Throughput , Responsetime , WEB_ERRORS , CPU , CPU_MIN , CPU_MAX , MEM , MEM_MIN , MEM_MAX
0 , 2 , 512M , 4 , 1024M , 21.5 , 418 , 0	,.2365972 , .230064171307710832 , .23854950244808130	, 208.7033 , 208 , 210 
1 , 2 , 512M , 4 , 1024M , 20.7 , 433 , 0	,.2874981 , .24280888070042253 , .30134062341363525	, 216.0819 , 213 , 218 
0 , 2 , 512M , 4 , 1024M , 27.0 , 530 , 0	,.37268359 , .35786969993606027 , .378299495656441979	, 372.4612 , 368 , 372 
1 , 2 , 512M , 4 , 1024M , 31.2 , 533 , 0	,.36303597 , .345283521075791429 , .3950907877269441885, 372.9667 , 369 , 372 

```
Above image shows the log of the load run i.e, throghput, response time, total memory used by the pod, total cpu used by the pod, minimum cpu, maximum cpu, minimum memory, maximum memory, cluster memory usage in percentage,cluster cpu in percentage, cpu request, memory request and web errors if any.

For CPU and Memory details refer Metrics-cpu.log and Metrics-mem.log . And for individual informations look into the logs generated during the run.
