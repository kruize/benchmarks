# Instructions to run the petclinic application using scripts 
**The scripts written supports**
- [Docker](#Docker)
- [Minikube](#Minikube)
- [Openshift](#Openshift)

## Docker
Create the required setup
`./scripts/petclinic-setup.sh setup_info`

**setup_info**: (do_setup/use_image)

- **do_setup**: Builds the petclinic application from the scratch by cloning the spring-petclinic repository and creates the images required for the setup.
- **use_image**: Uses already built petclinic image 

Pre-requisites for do_setup: javac and git 

`./scripts/petclinic-setup.sh do_setup javaimage`

**javaimage**: By default `adoptopenjdk/openjdk11-openj9:latest` will be considered as java image . if you want to use other java images then you can mention it explicitly.

To add any JVM parameters use JVM_ARGS variable while starting the container. The image which u have with openj9 uses - "Xshareclasses:none" . 

Example to build and run the petclinic application from the scratch

**`$./scripts/petclinic-setup.sh do_setup adoptopenjdk/openjdk11:latest`**
```
Checking prereqs...done
Building petclinic application...done
Building jmeter with petclinic driver...done
Running petclinic with inbuilt db...done
```
 
In case of `use_image` by default it uses `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0` for petclinic application and `kruize/jmeter_petclinic:3.1` for jmeter. If you want to use custom images then you need to mention it explicitly.

Example to run the petclinic application using built in image

**`$./scripts/petclinic-setup.sh use_image kruize/spring_petclinic:2.2.0-jdk-11.0.8-hotspot kruize/jmeter_petclinic:3.1`**
```
Checking prereqs...done
Pulling the jmeter image...done
Running petclinic with inbuilt db...done

```
## Minikube
To deploy the benchmark use `petclinic-deploy-minikube.sh`

`./scripts/petclinic-deploy-openshift.sh manifest_dir`

**manifest_dir**: Path where the manifest directory exists

**`$./scripts/petclinic-deploy-minikube.sh manifests/`** 
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
servicemonitor.monitoring.coreos.com/petclinic-0 created
deployment.apps/petclinic-sample-0 created
service/petclinic-service-0 created

```
## Openshift
To deploy the benchmark use `petclinic-deploy-openshift.sh`

`./scripts/petclinic-deploy-openshift.sh deploy_info`

**deploy_info**: Benchmark server , Namespace and Manifests directory 

- **Benchmark server**: Name of the cluster you are using
- **Namespace**: openshift-monitoring
- **Manifests directory**: Path where the manifest directory exists

**`./scripts/petclinic-deploy-openshift.sh rouging.os.fyre.ibm.com openshift-monitoring manifests/`**
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

**load_info**: [load type] [Number of iterations of the jmeter load] [ip_addr / namespace]"
- **load type**: docker icp openshift
- **Number of iterations of the jmeter load**: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.
- **ip_addr**: IP address of the machine. It is optional, if it is not specified then the get_ip function written inside the script will get the IP address of the machine.

`jmeter-petclinic:3.1` is the image used to apply the load

Example to run the load on openshift cluster

**`./scripts/petclinic-load.sh openshift 2`**
```
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
****
# Note for RHEL 8.0 users
podman docker should have the latest network version to work.















