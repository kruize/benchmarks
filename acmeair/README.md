# Instructions to run the acmeair application using scripts 
**The scripts written supports**
- [Docker](#Docker)
- [Minikube](#Minikube)
- [Openshift](#Openshift)

## Docker
Create the required setup
`./scripts/acmeair-setup.sh setup_info`

Builds the acmeair application from the scratch using the acmeair source files and creates the images required for the setup.

Example to build and run the acmeair application 

- **use_source_code**: Builds the acmeair application from the scratch by using the source code and creates the images required for the setup.
- **use_image**: Uses already built petclinic image 

Example to build and run the acmeair application from the scratch

**`$./scripts/acmeair-setup.sh setup_info use_source_code`**

```
Checking prereqs...done
Building acmeair application...done
Building acmeair driver...done
Building jmeter with acmeair driver...done
Running acmeair and mongo db...done

```
In case of `use_image` by default it uses `dinogun/acmeair-monolithic:latest` for acmeair application . If you want to use custom images then you need to mention it explicitly.

Example to run the petclinic application using built in image

**`./scripts/acmeair-setup.sh use_image shruthi07acharya/acmeair_mono_service_liberty:latest`**

```
Checking prereqs...done
Pulling the jmeter image...done
Running acmeair and mongo db...done
```

# Minikube
To deploy the benchmark use `acmeair-deploy-minikube.sh`

`./scripts/acmeair-deploy-openshift.sh manifest_dir`

**manifest_dir**: Path of the directory, which containes the yaml files

**`$./scripts/acmeair-deploy-minikube.sh manifests/`** 

```
~/benchmarks/acmeair ~/benchmarks/acmeair
No resources found.
deployment.apps/acmeair-db created
service/acmeair-db created
deployment.apps/acmeair-sample created
service/acmeair-service created

```
# Openshift
To deploy the benchmark use `acmeair-deploy-openshift.sh`

`./scripts/acmeair-deploy-openshift.sh deploy_info`

**deploy_info**: Benchmark server , Namespace , Manifests directory and Results directory path

- **Benchmark server**: Name of the cluster you are using
- **Namespace**: default
- **Manifests directory**: Path where the manifest directory exists
- **Results directory path**: Location where you want to store the results

**`$./scripts/acmeair-deploy-openshift.sh rouging.os.fyre.ibm.com default manifests/ result/`**

```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
deployment.apps/petclinic-sample-0 created
service/petclinic-service-0 created
route.route.openshift.io/petclinic-service-0 exposed

```

# Run the load
Simulating the load on petclinic benchmarks using jmeter
`./scripts/acmeair-load.sh load_info`

**load_info**: [load type] [Number of iterations of the jmeter load] [ip_addr / namespace]"
- **load type**: docker icp openshift
- **Number of iterations of the jmeter load**: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.
- **ip_addr**: IP address of the machine. It is optional, if it is not specified then the get_ip function written inside the script will get the IP address of the machine.

`jmeter:3.1` is the image used to apply the load

Example to run the load on openshift cluster

**`./scripts/acmeair-load.sh openshift 2`**

```
#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################

Loaded flights and 150 customers in 2.079 seconds 
Updated 1 path from the index
Running jmeter load with the following parameters
docker run --rm -v /home/shruthi/benchmarks/acmeair:/opt/app dinogun/jmeter:3.1 jmeter -Jdrivers=150 -Jduration=20 -Jhost=acmeair-service-default.apps.rouging.os.fyre.ibm.com -n -t /opt/app/acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx -DusePureIDs=true -l /opt/app/logs/jmeter.1.log -j /opt/app/logs/jmeter.1.log

#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################

Loaded flights and 300 customers in 2.113 seconds 
Updated 1 path from the index
Running jmeter load with the following parameters
docker run --rm -v /home/shruthi/benchmarks/acmeair:/opt/app dinogun/jmeter:3.1 jmeter -Jdrivers=300 -Jduration=20 -Jhost=acmeair-service-default.apps.rouging.os.fyre.ibm.com -n -t /opt/app/acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx -DusePureIDs=true -l /opt/app/logs/jmeter.2.log -j /opt/app/logs/jmeter.2.log
Updated 1 path from the index
#########################################################################################
				Displaying the results				       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,59.5,2410,439,0
2,119.2,4847,438,0

```
Above image shows the logs of the load run, it processes and displays the output for each run in Displaying the results section of the log which includes throughput, Number of pages it has retreived, average response time and errors if any.

To run the load for multiple instances in case of openshift cluster follow [README.md](/acmeair/scripts/perf/README.md)

# Cleanup
`$ ./scripts/acmeair-cleanup.sh`

# Note for RHEL 8.0 users
podman docker should have the latest network version to work.












