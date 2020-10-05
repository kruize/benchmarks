# Instructions to run the petclinic application using scripts 

# Create the required setup
Generate the images required for the setup 
`./scripts/petclinic-setup.sh setup_info`

setup_info: (do_setup/use_image)

do_setup : Build the setup using jar files

Pre-requisites: javac and git 

```
$./scripts/petclinic-setup.sh do_setup
Checking prereqs...done
Building petclinic application...done
Building jmeter with petclinic driver...done
Running petclinic with inbuilt db...done
```
use_image : Use the image to create the setup
`use_image petclinic_imagename jmeter_imagename`


```
$./scripts/petclinic-setup.sh use_image kruize/spring-petclinic:2.2.0 kruize/jmeter_petclinic:3.1
Checking prereqs...done
Pulling the jmeter image...done
Running petclinic with inbuilt db...done

```

both `petclinic_imagename` and `jmeter_imagename` are optional, If the image names are not specified then the default image `kruize/spring-petclinic:2.2.0` will be considered for petclinic and `kruize/jmeter_petclinic:3.1` will be considered for jmeter.

```
$ ./scripts/petclinic-setup.sh use_image 
Checking prereqs...done
Pulling the jmeter image...done
Running petclinic with inbuilt db...done
```

# Run the load
Apply the load to the benchmark
`./scripts/petclinic-load.sh load_info`

load_info: [load type] [Number of iterations of the jmeter load] [ip_addr / namespace]"

load type: docker icp openshift

Number of iterations of the jmeter load: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.

ip_addr: IP address of the machine. It is optional, if is not specified then the get_ip function written inside the script will get the IP address of the machine.

`jmeter-petclinic:3.1` is the image used to apply the load


```
$./scripts/petclinic-load.sh docker 2 
#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################
Running jmeter load with the following parameters
JHOST=192.168.1.8 JDURATION=20 JUSERS=150 JPORT=32334 
jmter logs Dir : /home/shruthi/kruize/tests/Spring-petclinic/logs/petclinic-202009111154
#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################
Running jmeter load with the following parameters
JHOST=192.168.1.8 JDURATION=20 JUSERS=300 JPORT=32334 
jmter logs Dir : /home/shruthi/kruize/tests/Spring-petclinic/logs/petclinic-202009111154
#########################################################################################
				Displaying the results				       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,310.7,6281,60,0
2,687.1,14059,25,0
```
Above image shows the logs of the load run, and it processes and displays the output at the end

# Cleanup
`$ ./scripts/petclinic-cleanup.sh`


# Note for RHEL 8.0 users
podman docker should have the latest network version to work.

# Openshift
To deploy the benchmark use `petclinic-deploy-openshift.sh`


`./scripts/petclinic-deploy-openshift.sh deploy_info`

deploy_info: Benchmark server , Namespace , Manifests directory and Results directory path

Benchmark server: Name of the cluster you are using

Namespace: openshift-monitoring

Manifests directory: Path where the manifest directory exists

Results directory path: Location where you want to store the results

```
$./scripts/petclinic-deploy-openshift.sh rouging.os.fyre.ibm.com openshift-monitoring manifests/ result/
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
deployment.apps/petclinic-sample-0 created
service/petclinic-service-0 created
route.route.openshift.io/petclinic-service-0 exposed

```

Run the load

```
./scripts/petclinic-load.sh openshift 2

#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################

Running jmeter load with the following parameters
JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com JDURATION=20 JUSERS=150 JPORT=8080 
jmter logs Dir : /root/rt-cloud-benchmarks/spring-petclinic/logs/petclinic-202010052035

#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################

Running jmeter load with the following parameters
JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com JDURATION=20 JUSERS=300 JPORT=8080 
jmter logs Dir : /root/rt-cloud-benchmarks/spring-petclinic/logs/petclinic-202010052035
#########################################################################################
				Displaying the results				       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,142.8,3117,435,0
2,267.2,6229,438,0


```

To run the load for multiple instances and for multiple iterations `./scripts/perf/run_petclinic_openshift.sh load_info perf_info`

load_info : BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH JMETER_LOAD_USERS JMETER_LOAD_DURATION WARMUPS MEASURES 

BENCHMARK_SERVER_NAME : Name of the cluster you are using

NAMESPACE : openshift-monitoring

RESULTS_DIR_PATH : Location where you want to store the results

JMETER_LOAD_USERS : Number of users

JMETER_LOAD_DURATION : Load duration

WARMUPS : Number of warmups

MEASURES : Number of measures

perf_info is optional , it can be used in case of multiple instances

perf_info: TOTAL_INST TOTAL_ITR RE_DEPLOY MANIFESTS_DIR

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
##### warmup 1
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
##### warmup 2
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
##### warmup 3
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
##### warmup 4
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
Running 3 measures for 300 users
##### measure 0
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
##### measure 1
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
##### measure 2
Collecting CPU & MEM details of nodes worker0.rouging.os.fyre.ibm.com  and cluster
APP_NAME is ... petclinic
Running jmeter load with the following parameters
CMD = docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=60 -e JUSERS=300 kusumach/petclinic_jmeter_noport:0423
Parsing results for 1 instances

```






