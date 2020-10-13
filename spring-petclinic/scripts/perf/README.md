# To run the load for multiple instances and for multiple iterations 

`./scripts/perf/run_petclinic_openshift.sh load_info perf_info` 

load_info : BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH JMETER_LOAD_USERS JMETER_LOAD_DURATION WARMUPS MEASURES

BENCHMARK_SERVER_NAME : Name of the cluster you are using

NAMESPACE : openshift-monitoring

RESULTS_DIR_PATH : Location where you want to store the results

JMETER_LOAD_USERS : Number of users

JMETER_LOAD_DURATION : Load duration

WARMUPS : Number of warmups

MEASURES : Number of measures

perf_info is optional , it can be used in case of multiple instances

erf_info: TOTAL_INST TOTAL_ITR RE_DEPLOY MANIFESTS_DIR

TOTAL_INST: Number of instances

TOTAL_ITR: Number of times you want to run the load

RE_DEPLOY: true

MANIFESTS_DIR: Path where the manifest directory exists


```
$./scripts/perf/run_petclinic_openshift.sh rouging.os.fyre.ibm.com openshift-monitoring result/ 300 60 5 3
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
RESULTS DIRECTORY is  result//petclinic-202010051904
Running the benchmark with 1  instances with 1 iterations having 5 warmups and 3 measurements
Running 5 warmups for 300 users
##### warmup 0
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423

...
...
...


##### measure 2
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
Parsing results for 1 instances

```

