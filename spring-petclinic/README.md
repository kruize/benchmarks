# Instructions to run the petclinic application using scripts 
**The scripts written supports**
- [Docker](#Docker)
- [Minikube](#Minikube)
- [Openshift](#Openshift)

# Create custom images
Generate custom petclinic images required for the setup 
`./scripts/build.sh `

Pre-requisites: javac and git 

`./scripts/build.sh baseimage`

baseimage: baseimage for petclinic. It is optional, if it is not specified then the default image `adoptopenjdk/openjdk11-openj9:latest` will be considered as base image.

The image which u have with openj9 uses - "Xshareclasses:none" . Include the required JVM_ARGS in petclinic Dockerfile

Example to build the custom image for petclinic application

**`$./scripts/build.sh adoptopenjdk/openjdk11-openj9:latest`**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
Checking prereqs...done
Building petclinic application...done
Building jmeter with petclinic driver...done

```
## Docker
 To deploy the benchmark use `petclinic-deploy-docker.sh`
 
`./scripts/petclinic-deploy-docker.sh Total_instances Petclinic_image JVM_ARGS`

- **Total_instances**: Number of petclinic instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **petclinic_image**: Petclinic image to be used to deploy petclinic. It is optional, if is not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be considered for the deployment.
- **JVM_ARGS**: JVM agruments if any

Example to deploy petclinic application using custom image

**`$./scripts/petclinic-deploy-docker.sh 1 spring-petclinic:latest -Xshareclasses:none`**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
Checking prereqs...done
Using custom petclinic image spring-petclinic:latest... 
Pulling the jmeter image...done
Running petclinic instance 1 with inbuilt db...
Creating Kruize network: kruize-network...done

```
 
Example to deploy and run multiple petclinic application instances using default image

**`$./scripts/petclinic-deploy-docker.sh 2`**
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

`./scripts/petclinic-deploy-openshift.sh manifest_dir Total_instances petclinic_image`

- **manifest_dir**: Path where the manifest directory exists
- **Total_instances**: Number of petclinic instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **petclinic_image**: Petclinic image to be used to deploy petclinic. It is optional, if is not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be considered for the deployment.

Example to deploy and run multiple petclinic application instances on docker

**`$./scripts/petclinic-deploy-minikube.sh manifests 2/`** 
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

`./scripts/petclinic-deploy-openshift.sh deploy_info Total_instances petclinic_image`

**deploy_info**: Benchmark server , Namespace and Manifests directory 

- **Benchmark server**: Name of the cluster you are using
- **Namespace**: openshift-monitoring
- **Manifests directory**: Path where the manifest directory exists
- **Total_instances**: Number of petclinic instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **petclinic_image**: Petclinic image to be used to deploy petclinic. It is optional, if is not specified then the default image `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` will be considered for the deployment.

**`./scripts/petclinic-deploy-openshift.sh rouging.os.fyre.ibm.com openshift-monitoring manifests/2`**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
servicemonitor.monitoring.coreos.com/petclinic-0 created
deployment.apps/petclinic-sample-0 created
service/petclinic-service-0 created
route.route.openshift.io/petclinic-service-0 exposed
```

# Run the load
Simulating the load on petclinic benchmarks using jmeter
`./scripts/petclinic-load.sh load_info`

**load_info**: [load type] [Total Number of instances] [Number of iterations of the jmeter load] [ip_addr / namespace]"
- **load type**: docker icp openshift
- **Total Number of instances**: Number of petclinic instances to which you want to run the load.  It is optional, if is not specified then by default it will be considered as 1 instance. 
- **Number of iterations of the jmeter load**: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.
- **ip_addr**: IP address of the machine. It is optional, if it is not specified then the get_ip function written inside the script will get the IP address of the machine.

`jmeter-petclinic:3.1` is the image used to apply the load

Example to run the load on minikube

**`$./scripts/petclinic-load.sh minikube 2 2`**
```

#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################

Running jmeter load for instance  with the following parameters
docker run --rm -e JHOST=172.17.0.2 -e JDURATION=20 -e JUSERS=150 -e JPORT=32334 jmeter_petclinic:3.1
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011222111

#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################

Running jmeter load for instance  with the following parameters
docker run --rm -e JHOST=172.17.0.2 -e JDURATION=20 -e JUSERS=300 -e JPORT=32334 jmeter_petclinic:3.1
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011222111
#########################################################################################
				Displaying the results					       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,44.1,1397,4475,0
2,44.1,1397,4475,0

#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################

Running jmeter load for instance  with the following parameters
docker run --rm -e JHOST=172.17.0.2 -e JDURATION=20 -e JUSERS=150 -e JPORT=32335 jmeter_petclinic:3.1
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011222111

#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################

Running jmeter load for instance  with the following parameters
docker run --rm -e JHOST=172.17.0.2 -e JDURATION=20 -e JUSERS=300 -e JPORT=32335 jmeter_petclinic:3.1
jmter logs Dir : /home/shruthi/benchmarks/spring-petclinic/logs/petclinic-202011222111
#########################################################################################
				Displaying the results					       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,18.5,852,12323,0
2,18.5,852,12323,0

```
Above image shows the logs of the load run, it processes and displays the output for each run. See Displaying the results section of the log for information about throughput, Number of pages it has retreived, average response time and errors if any.

To test with multiple instances follow [README.md](/spring-petclinic/scripts/perf/README.md)

# Cleanup
`$ ./scripts/petclinic-cleanup.sh`

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















