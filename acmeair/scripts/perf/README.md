# Test with multiple instances 

`./scripts/perf/run_acmeair_openshift.sh  -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-u JMETER_LOAD_USERS] [-d JMETER_LOAD_DURATION] [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-a ACMEAIR_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] [--env=ENV_VAR]` 

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
- **ENV_VAR**: Environment variable

Example to test with multiple instances

**`$./scripts/perf/run_acmeair_openshift.sh -s rouging.os.fyre.ibm.com -e result -u 50 -d 20 -w 3 -m 2 -i 2 --iter=1 -r --cpureq=2 --cpulim=4 --memreq=512M --memlim=1024M`**

``` 
Instances , Throughput , Responsetime , MEM_MEAN , CPU_MEAN , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , CLUSTER_MEM% , CLUSTER_CPU% , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , WEB_ERRORS 
1 ,  14.575 , 636 , 207.54 , 0.211182 , .18365898198238238 , .2307142678958271 , 203 , 213 , 37.8111 , 20.6886 , 2 , 512M ,4 , 1024M , 0
2 ,  15.675 , 2555.75 , 413.681 , 0.364557 , .32643521314549026 , .409287520308128886 , 405 , 425 , 38.9246 , 21.6761 , 2 , 512M ,4 , 1024M , 0
Run , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , Throughput , Responsetime , WEB_ERRORS , CPU , CPU_MIN , CPU_MAX , MEM , MEM_MIN , MEM_MAX
0 , 2 , 512M , 4 , 1024M , 14.2 , 648 , 0	,.203360 , .18365898198238238 , .210822274192551826	, 205.3278 , 203 , 207 
1 , 2 , 512M , 4 , 1024M , 17.0 , 539 , 0	,.2138073 , .186235097837714044 , .220351552433845024	, 206.8657 , 204 , 213 
0 , 2 , 512M , 4 , 1024M , 14.2 , 648 , 0	,.203360 , .18365898198238238 , .210822274192551826	, 205.3278 , 203 , 207 
1 , 2 , 512M , 4 , 1024M , 17.0 , 539 , 0	,.2138073 , .186235097837714044 , .220351552433845024	, 206.8657 , 204 , 213 
0 , 2 , 512M , 4 , 1024M , 12.8 , 716 , 0	,.2098883 , .207167223712054166 , .212585030601502565	, 207.5193 , 204 , 212 
1 , 2 , 512M , 4 , 1024M , 14.3 , 641 , 0	,.2176719 , .20356276764054909 , .2307142678958271	, 210.4465 , 207 , 211 
0 , 2 , 512M , 4 , 1024M , 15.7 , 1245 , 0	,.3571415 , .329364788189071308 , .367147959850883422	, 406.7486 , 405 , 407 
1 , 2 , 512M , 4 , 1024M , 15.4 , 1295 , 0	,.3816765 , .32643521314549026 , .409287520308128886	, 413.7360 , 409 , 423 
0 , 2 , 512M , 4 , 1024M , 15.7 , 1245 , 0	,.3571415 , .329364788189071308 , .367147959850883422	, 406.7486 , 405 , 407 
1 , 2 , 512M , 4 , 1024M , 15.4 , 1295 , 0	,.3816765 , .32643521314549026 , .409287520308128886	, 413.7360 , 409 , 423 
0 , 2 , 512M , 4 , 1024M , 15.2 , 1320 , 0	,.3472396 , .339862358898334090 , .357458597858074368	, 417.0604 , 411 , 419 
1 , 2 , 512M , 4 , 1024M , 16.4 , 1150 , 0	,.3721707 , .35076403423513481 , .384480312052044784	, 417.1794 , 414 , 425 

```
Above image shows the log of the load run i.e, throghput, response time, total memory used by the pod, total cpu used by the pod, minimum cpu, maximum cpu, minimum memory, maximum memory, cluster memory usage in percentage,cluster cpu in percentage, cpu request, memory request and web errors if any.

For CPU and Memory details refer Metrics-cpu.log and Metrics-mem.log . And for individual informations look into the logs generated during the run.
