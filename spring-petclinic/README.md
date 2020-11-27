# Instructions to run the petclinic application using scripts 
**The scripts written supports**
- [Docker](#Docker)
- [Minikube](#Minikube)
- [Openshift](#Openshift)

# Create custom images
Generate custom petclinic images required for the setup 
`./scripts/petclinic-build.sh `

Pre-requisites: javac and git 

`./scripts/petclinic-build.sh [baseimage]`

baseimage: baseimage for petclinic. It is optional, if it is not specified then the default image `adoptopenjdk/openjdk11-openj9:latest` will be considered as base image.

The image which u have with openj9 uses - "Xshareclasses:none" . Include the required JVM_ARGS in petclinic Dockerfile

Example to build the custom image for petclinic application

**`$./scripts/petclinic-build.sh adoptopenjdk/openjdk11-openj9:latest`**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
Checking prereqs...done
Building petclinic application...done
Building jmeter with petclinic driver...done

```
## Docker
 To deploy the benchmark use `petclinic-deploy-docker.sh`
 
`./scripts/petclinic-deploy-docker.sh [-i SERVER_INSTANCES] [-p PETCLINIC_IMAGE] [-a JVM_ARGS]`

- **SERVER_INSTANCES**: Number of petclinic instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **PETCLINIC_IMAGE**: Petclinic image to be used to deploy petclinic. It is optional, if is not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be considered for the deployment.
- **JVM_ARGS**: JVM agruments if any

Example to deploy petclinic application using custom image

**`$./scripts/petclinic-deploy-docker.sh -i 1 -p spring-petclinic:latest -a -Xshareclasses:none`**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
Checking prereqs...done
Using custom petclinic image spring-petclinic:latest... 
Pulling the jmeter image...done
Running petclinic instance 1 with inbuilt db...
Creating Kruize network: kruize-network...done

```
 
Example to deploy and run multiple petclinic application instances using default image

**`$./scripts/petclinic-deploy-docker.sh -i 2`**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
Checking prereqs...done
Pulling the jmeter image...done
Running petclinic instance 1 with inbuilt db...
Creating Kruize network: kruize-network...done
Running petclinic instance 2 with inbuilt db...
kruize-network already exists...done

```
## Minikube
To deploy the benchmark use `petclinic-deploy-minikube.sh `

`./scripts/petclinic-deploy-minikube.sh [-i SERVER_INSTANCES] [-p PETCLINIC_IMAGE]`

- **SERVER_INSTANCES**: Number of petclinic instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **PETCLINIC_IMAGE**: Petclinic image to be used to deploy petclinic. It is optional, if is not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be considered for the deployment.

Example to deploy and run multiple petclinic application instances on minikube

**`$./scripts/petclinic-deploy-minikube.sh -i 2/`** 
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
servicemonitor.monitoring.coreos.com/petclinic-0 created
servicemonitor.monitoring.coreos.com/petclinic-1 created
deployment.apps/petclinic-sample-0 created
service/petclinic-service-0 created
deployment.apps/petclinic-sample-1 created
service/petclinic-service-1 created

```
## Openshift
To deploy the benchmark use `petclinic-deploy-openshift.sh`

`./scripts/petclinic-deploy-openshift.sh -s BENCHMARK_SERVER [-i SERVER_INSTANCES] [-p PETCLINIC_IMAGE] [--cpureq=CPU_REQ] [--memreq MEM_REQ] [--cpulim=CPU_LIM] [--memlim MEM_LIM]`

- **BENCHMARK_SERVER**: Name of the cluster you are using
- **SERVER_INSTANCES**: Number of petclinic instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **PETCLINIC_IMAGE**: Petclinic image to be used to deploy petclinic. It is optional, if is not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be considered for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit

Example to deploy and run petclinic application on openshift cluster

**`./scripts/petclinic-deploy-openshift.sh -s rouging.os.fyre.ibm.com `**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
servicemonitor.monitoring.coreos.com/petclinic-0 created
deployment.apps/petclinic-sample-0 created
service/petclinic-service-0 created
route.route.openshift.io/petclinic-service-0 exposed
```

# Run the load
Simulating the load on petclinic benchmarks using jmeter
`./scripts/petclinic-load.sh -c CLUSTER_TYPE [-i SERVER_INSTANCES] [-l MAX_LOOP] [-a IP_ADDR]`

- **CLUSTER_TYPE**: docker icp openshift
- **SERVER_INSTANCES**: Number of petclinic instances to which you want to run the load.  It is optional, if is not specified then by default it will be considered as 1 instance. 
- **MAX_LOOP**: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.
- **IP_ADDR**: IP address of the machine. It is optional, if it is not specified then the get_ip function written inside the script will get the IP address of the machine.

`kruize/jmeter_petclinic:noport` is the image used to apply the load

Example to run the load on 2 petclinic instances for 2 iterations in openshift cluster

**`$./scripts/petclinic-load.sh -c openshift -i 2 -l 2`**
```

#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################
Running jmeter load for petclinic instance 1 with the following parameters
docker run  --rm -e JHOST=petclinic-service-1-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=20 -e JUSERS=150 kruize/jmeter_petclinic:noport
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011241746
#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################
Running jmeter load for petclinic instance 1 with the following parameters
docker run  --rm -e JHOST=petclinic-service-1-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=20 -e JUSERS=300 kruize/jmeter_petclinic:noport
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011241746
#########################################################################################
				Displaying the results				       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,72.1,1705,1096,0
2,113.3,2895,1329,0
#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################
Running jmeter load for petclinic instance 2 with the following parameters
docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=20 -e JUSERS=150 kruize/jmeter_petclinic:noport
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011241746
#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################
Running jmeter load for petclinic instance 2 with the following parameters
docker run  --rm -e JHOST=petclinic-service-0-openshift-monitoring.apps.rouging.os.fyre.ibm.com -e JDURATION=20 -e JUSERS=300 kruize/jmeter_petclinic:noport
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011241746
#########################################################################################
				Displaying the results				       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,66.7,1738,1071,0
2,116.9,3007,1282,0
```
Above image shows the logs of the load run, it processes and displays the output for each run. See Displaying the results section of the log for information about throughput, Number of pages it has retreived, average response time and errors if any.

To test with multiple instances follow [README.md](/spring-petclinic/scripts/perf/README.md)

# Cleanup
`$ ./scripts/petclinic-cleanup.sh cluster_type[docker|minikube|openshift]`

# Changes to be done to get kruize runtime recommendations for petclinic
**Add the following in**

- **pom.xml file**

```
<!-- Micrometer Prometheus registry  -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```
- **Application.properties**
```
#Since cadvisor uses the port 8080, use the port 8081
server.port=8081
#management
management.endpoints.web.base-path=/manage
```
Compile and build the application 

- **Use 8081 for port mapping**

- **Add petclinic as target in kruize/manifests/docker/prometheus.yaml**
```
- job_name: petclinic-app
  honor_timestamps: true
  scrape_interval: 2s
  scrape_timeout: 1s
  metrics_path: /manage/prometheus
  scheme: http
  static_configs:
  - targets:
      - petclinic-app:8081
```

# Note for RHEL 8.0 users
podman docker should have the latest network version to work.















