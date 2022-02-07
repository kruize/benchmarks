# Instructions to run the TechEmpower Framework (Quarkus) application using scripts 
**The scripts written supports**
- [Openshift](#Openshift)

Pre-requisites: java11 , git , wget , zip , unzip , php , bc , jq on client machine.

tfb-qrh represents TechEmpower Framework benchmark - [Quarkus resteasy-hibernate](https://github.com/TechEmpower/FrameworkBenchmarks/tree/master/frameworks/Java/quarkus)

Example to deploy and run multiple tfb-qrh application instances using default image

```
## Openshift

To run the benchmark on openshift cluster to collect performance metrics

`./scripts/perf/run-tfb-qrh-openshift.sh -s BENCHMARK_SERVER -e RESULTS_DIR [--dbtype=DB_TYPE] [--dbhost=DB_HOST] [-i SERVER_INSTANCES] [-n NAMESPACE] [-g TFB_IMAGE] [-d DURATION] [-w WARMUPS] [-m MEASURES] [--iter ITERATIONS] [-t THREADS] [-R RATE] [--connection CONNECTIONS] [-r RE_DEPLOY] [--cpureq=CPU_REQ] [--memreq MEM_REQ] [--cpulim=CPU_LIM] [--memlim MEM_LIM] [--usertunables=USER_TUNABLES] [--MaxInlineLevel=MAXINLINELEVEL] [--quarkustpcorethreads==QUARKUS_THREADPOOL_CORETHREADS] [quarkustpqueuesize=QUARKUS_THREADPOOL_QUEUESIZE] [--quarkusdatasourcejdbcminsize=QUARKUS_DATASOURCE_JDBC_MINSIZE] [--quarkusdatasourcejdbcmaxsize=QUARKUS_DATASOURCE_JDBC_MAXSIZE]`

- **BENCHMARK_SERVER**: Name of the cluster you are using
- **RESULTS_DIR**: Directory to store results
- **DB_TYPE**: Supports only options : DOCKER , STANDALONE. Default is DOCKER.
- **DB_HOST**: Hostname of the database if DB_TYPE selected is STANDALONE.
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
- **USER_TUNABLES**: Any specific tunable user want to mention. If there are multiple entires, it should be separated by ; and enclosed with ""
- **MAXINLINELEVEL**: Maxinline level tunable for JVM.
- **QUARKUS_THREADPOOL_CORETHREADS**: quarkus.thread-pool.core.threads property for Quarkus.
- **QUARKUS_THREADPOOL_QUEUESIZE**: quarkus.thread-pool.queue.size property for Quarkus.Memory limit
- **QUARKUS_DATASOURCE_JDBC_MINSIZE**: quarkus.data-source.jdbc.min.size property for Quarkus.
- **QUARKUS_DATASOURCE_JDBC_MAXSIZE**: quarkus.data-source.jdbc.min.size property for Quarkus.

Example:
`./scripts/perf/run-tfb-qrh-openshift.sh -s <example.com> -e results -r -d 60 -w 20 -m 3 -i 1 --iter=5 -n default -t 3 -R 200 --connection=200 --cpureq=1.31 --memreq=648M --cpulim=1.3 --memlim=648M --maxinlinelevel=44 --quarkustpcorethreads=22 --quarkustpqueuesize=950 --quarkusdatasourcejdbcminsize=8 --quarkusdatasourcejdbcmaxsize=36`
```

**Sample Output and Description:**

```
INSTANCES ,  THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m , MAX_RESPONSE_TIME , RESPONSE_TIME_50p , RESPONSE_TIME_95p , RESPONSE_TIME_98p , RESPONSE_TIME_99p , RESPONSE_TIME_999p , CPU_USAGE , MEM_USAGE , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , THRPT_PROM_CI , RSPTIME_PROM_CI , THROUGHPUT_WRK , RESPONSETIME_WRK , RESPONSETIME_MAX_WRK , RESPONSETIME_STDEV_WRK , WEB_ERRORS , THRPT_WRK_CI , RSPTIME_WRK_CI , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , MAXINLINELEVEL , QRKS_TP_CORETHREADS , QRKS_TP_QUEUESIZE , QRKS_DS_JDBC_MINSIZE , QRKS_DS_JDBC_MAXSIZE
1 , 209.552 , 10.2 , 6570.3370969999995000 ,  ,  ,  ,  ,  , 0.113158 , 345.929 ,.10653005617777772 , .1209623125675936 , 333 , 371 , 0.52 , 43.37 , 198.831 , 33.7027 , 1190.00 , 46.10 , 0 , 0.5 , 9.86  , 1.31 , 648M , 1.31 , 648M , 44 , 22 , 950 , 8 , 36


**INSTANCES** : No.of application instances
**THROUGHPUT_RATE_3m**: Rate of Throughput for last 3 mins from prometheus data.
**RESPONSE_TIME_RATE_3m**: Rate of Responsetime for last 3 mins from prometheus data.
**MAX_RESPONSE_TIME**: Max responsetime observed during the whole run from prometheus data
**RESPONSE_TIME_50p , RESPONSE_TIME_95p , RESPONSE_TIME_98p , RESPONSE_TIME_99p , RESPONSE_TIME_999p**: Percentile information of responsetime from prometheus data. **NOT AVAILABLE CURRENTLY**.
**CPU_USAGE**: Average of CPU consumed.
**MEM_USAGE**: Average of Memory consumed.
**CPU_MIN**: Minimum value of cpu during the run.
**CPU_MAX**: Maximum value of cpu during the run.
**MEM_MIN**:Minimum value of memory consumed during the run.
**MEM_MAX**: Maximum value of memory consumed during the run.
**THRPT_PROM_CI**: Confidence interval of prometheus throughput data.
**RSPTIME_PROM_CI**: Confidence interval of prometheus responsetime data.
**THROUGHPUT_WRK**: Throughput data from hyperfoil/wrk2 
**RESPONSETIME_WRK**: Response time data from hyperfoil/wrk2
**RESPONSETIME_MAX_WRK**: Maximum responsetime from hyperfoil/wrk2
**RESPONSETIME_STDEV_WRK**: standard deviation responsetime from hyperfoil/wrk2
**WEB_ERRORS**: Errors while running the load from hyperfoil/wrk2
**THRPT_WRK_CI**: Confidence interval of hyperfoil/wrk2 throughput data.
**RSPTIME_WRK_CI**: Confidence interval of hyperfoil/wrk2 responsetime data.
**CPU_REQ**: Configuration value of cpu request if set
**MEM_REQ**: Configuration value of memory request if set
**CPU_LIM**: Configuration value of cpu limit if set
**MEM_LIM**: Configuration value of memory limit if set
**MAXINLINELEVEL**: Configuration value of maxinlinelevel tunable of hotpsot JVM if set
**QRKS_TP_CORETHREADS**: Configuration value of quarkus.thread-pool.core.threads tunable of Quarkus if set
**QRKS_TP_QUEUESIZE**: Configuration value of quarkus.thread-pool.queue.size tunable of Quarkus if set
**QRKS_DS_JDBC_MINSIZE**: Configuration value of quarkus.data-source.jdbc.min.size tunable of Quarkus if set
**QRKS_DS_JDBC_MAXSIZE**: Configuration value of quarkus.data-source.jdbc.max.size tunable of Quarkus if set
```
**Note:** If the run fails, the output values would be **99999**. This is added for the convenience of experiments with autotune. For more details, look into setup.log as mentioned at the end of the run.

## Scripts Details

| Script Name                   |       What it does?                                                                                                                                           |
|-------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| perf/run-tfb-qrh-openshift.sh |       Main script to run the benchmark - which internally calls other scripts to deploy and run the load and collecting the metrics and parsing the data.     |
| tfb-qrh-deploy-openshift.sh   |       Deploy the benchmark with tunables                                                                                                                      |
| perf/getmetrics-promql.sh     |       Has prometheus queries that are required calculate the metrics required for objective function and the benchmark.                                       |
| perf/parsemetrics-promql.sh   |       Parse the prometheus metrics data to calculate the average , max and min values as per the requirement of the benchmark.                                |
| perf/ci.php			|	Use to measure confidence interval of data.														|
| perf/parsemetrics-wrk.sh      |       Parse the metrics data from hyperfoil/wrk load simulator.                                                                                               |

