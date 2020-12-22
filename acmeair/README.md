# Instructions to run the acmeair application using scripts 
**The scripts written supports**
- [Docker](#Docker)
- [Minikube](#Minikube)
- [Openshift](#Openshift)

# Create custom images
Generate custom acmeair images required for the setup
`./scripts/acmeair-build.sh`

Example to build the custom image for acmeair application

**`$./scripts/acmeair-setup.sh `**

```
Checking prereqs...done
Building acmeair application...done
Building acmeair driver...done
Building jmeter with acmeair driver...done

```

## Docker
To deploy the benchmark use `acmeair-deploy-docker.sh`
 
`./scripts/acmeair-deploy-docker.sh [-i SERVER_INSTANCES] [-a ACMEAIR_IMAGE] `

- **SERVER_INSTANCES**: Number of acmeair instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **ACMEAIR_IMAGE**: Acmeair image to be used to deploy acmeair. It is optional, if is not specified then the default image `dinogun/acmeair-monolithic:latest` will be considered for the deployment.

Example to deploy acmeair application using custom image

**`./scripts/acmeair-deploy-docker.sh  -i 1 -a acmeair_mono_service_liberty:latest`**

```
Checking prereqs...done
Using custom acmeair image acmeair_mono_service_liberty:latest... 
Pulling the jmeter image...done
Running 1 acmeair instance and mongo db...
Creating acmeair network: acmeair-net...
done
```

Example to deploy and run multiple acmeair application instances using default image

**`$./scripts/acmeair-deploy-docker.sh -i 2`**
```
Checking prereqs...done
Pulling the jmeter image...done
Running 1 acmeair instance and mongo db...
Creating acmeair network: acmeair-net...
done
Running 2 acmeair instance and mongo db...
Creating acmeair network: acmeair-net...
done

```

# Minikube
To deploy the benchmark use `acmeair-deploy-minikube.sh`

`./scripts/acmeair-deploy-openshift.sh [-i SERVER_INSTANCES] [-a ACMEAIR_IMAGE]`

- **SERVER_INSTANCES**: Number of acmeair instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **ACMEAIR_IMAGE**: Acmeair image to be used to deploy acmeair. It is optional, if is not specified then the default image `dinogun/acmeair-monolithic:latest` will be considered for the deployment.

**`$./scripts/acmeair-deploy-minikube.sh -i 2`** 

```
Removing the acmeair instances... 
done
deployment.apps/acmeair-db-0 created
service/acmeair-db-0 created
deployment.apps/acmeair-db-1 created
service/acmeair-db-1 created
deployment.apps/acmeair-sample-0 created
service/acmeair-service-0 created
deployment.apps/acmeair-sample-1 created
service/acmeair-service-1 created

```
# Openshift
To deploy the benchmark use `acmeair-deploy-openshift.sh`

`./scripts/acmeair-deploy-openshift.sh -s BENCHMARK_SERVER [-n NAMESPACE] [-i SERVER_INSTANCES] [-a ACMEAIR_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM]`

- **BENCHMARK_SERVER**: Name of the cluster you are using
- **SERVER_INSTANCES**: Number of acmeair instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **NAMESPACE**: Namespace in which acmeair application is to be deployed. It is optional, if not specified then `default` will be considered as the namespace. 
- **ACMEAIR_IMAGE**: Acmeair image to be used to deploy acmeair. It is optional, if is not specified then the default image `dinogun/acmeair-monolithic:latest` will be considered for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit

Example to deploy and run acmeair application on openshift cluster

**`$./scripts/acmeair-deploy-openshift.sh -s rouging.os.fyre.ibm.com -n default -i 2`**

```
Removing the acmeair instances... 
deployment.extensions "acmeair-db-0" deleted
deployment.extensions "acmeair-sample-0" deleted
service "acmeair-db-0" deleted
service "acmeair-service-0" deleted
route.route.openshift.io "acmeair-service-0" deleted
done
deployment.apps/acmeair-db-0 created
service/acmeair-db-0 created
deployment.apps/acmeair-db-1 created
service/acmeair-db-1 created
deployment.apps/acmeair-sample-0 created
service/acmeair-service-0 created
deployment.apps/acmeair-sample-1 created
service/acmeair-service-1 created
route.route.openshift.io/acmeair-service-0 exposed
route.route.openshift.io/acmeair-service-1 exposed

```

# Run the load
Simulating the load on acmeair benchmarks using jmeter
`./scripts/acmeair-load.sh -c CLUSTER_TYPE [-i SERVER_INSTANCES] [--iter=MAX_LOOP] [-n NAMESPACE] [-a IP_ADDR]`

- **CLUSTER_TYPE**: docker|minikube|openshift
- **SERVER_INSTANCES**: Number of acmeair instances to which you want to run the load.  It is optional, if is not specified then by default it will be considered as 1 instance. 
- **MAX_LOOP**: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.
- **NAMESPACE**: Namespace in which acmeair application is deployed(Required only in the case of openshift cluster and if the application is deployed in other namespaces except `default`)
- **IP_ADDR**: IP address of the machine. It is optional, if it is not specified then the get_ip function written inside the script will get the IP address of the machine.

`kruize/jmeter_acmeair:3.1` is the image used to apply the load

Example to run the load on openshift cluster

**`./scripts/acmeair-load.sh -c openshift --iter=2`**

```
#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################

Loaded flights and 150 customers in 1.74 seconds 
Updated 1 path from the index
Running jmeter load for petclinic instance 1 with the following parameters
docker run --rm -e Jdrivers=150 -e Jduration=20 -e Jhost=acmeair-service-0-default.apps.rouging.os.fyre.ibm.com kruize/jmeter_acmeair:3.1 
jmter logs Dir : /home/shruthi/benchmarks/acmeair/logs/acmeair-202012222039

#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################

Loaded flights and 300 customers in 1.449 seconds 
Updated 1 path from the index
Running jmeter load for petclinic instance 1 with the following parameters
docker run --rm -e Jdrivers=300 -e Jduration=20 -e Jhost=acmeair-service-0-default.apps.rouging.os.fyre.ibm.com kruize/jmeter_acmeair:3.1 
jmter logs Dir : /home/shruthi/benchmarks/acmeair/logs/acmeair-202012222039
Updated 1 path from the index
#########################################################################################
				Displaying the results					       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,20.5,840,1552,0
2,16.6,931,3622,0


```
Above image shows the logs of the load run, it processes and displays the output for each run in Displaying the results section of the log which includes throughput, Number of pages it has retreived, average response time and errors if any.

To run the load for multiple instances in case of openshift cluster follow [README.md](/acmeair/scripts/perf/README.md)

# Cleanup
`$ ./scripts/acmeair-cleanup.sh -c CLUSTER_TYPE[docker|minikube|openshift] [-n NAMESPACE]`

- **CLUSTER_TYPE**: docker|minikube|openshift
- **NAMESPACE**: Namespace in which acmeair application is deployed(Required only in the case of openshift cluster and if the application is deployed in other namespaces except `default`). 

# Note for RHEL 8.0 users
podman docker should have the latest network version to work.

Acmeair source file is cloned from [github repo] (https://github.com/sabkrish/acmeair.git)










