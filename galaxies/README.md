# Instructions to run the galaxies application using scripts 
**The scripts written supports**
- [Docker](#Docker)
- [Minikube](#Minikube)
- [Openshift](#Openshift)

# Create custom images
Generate custom galaxies images required for the setup
`./scripts/galaxies-build.sh`

Example to build the custom image for galaxies application

**`$./scripts/galaxies-build.sh `**

```
Checking prereqs...done
Building galaxies application...done

```

## Docker
To deploy the benchmark use `galaxies-deploy-docker.sh`
 
`./scripts/galaxies-deploy-docker.sh [-i SERVER_INSTANCES] [-g GALAXIES_IMAGE] `

- **SERVER_INSTANCES**: Number of galaxies instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **GALAXIES_IMAGE**: galaxies image to be used to deploy galaxies. It is optional, if is not specified then the default image `dinogun/galaxies:1.1-jdk-11.0.10_9` will be considered for the deployment.

Example to deploy galaxies application using custom image

**`./scripts/galaxies-deploy-docker.sh  -i 1 -g galaxies:latest`**

```
Checking prereqs...done
Using custom galaxies image galaxies:latest...
Running galaxies instance 1 with inbuilt db...
Creating Kruize network: kruize-network...
done
```

Example to deploy and run multiple galaxies application instances using default image

**`$./scripts/galaxies-deploy-docker.sh -i 2`**
```
Checking prereqs...done
Running galaxies instance 1 with inbuilt db...
Creating Kruize network: kruize-network...
done
Running galaxies instance 2 with inbuilt db...
kruize-network already exists...
done

```

# Minikube
To deploy the benchmark use `galaxies-deploy-minikube.sh`

`./scripts/galaxies-deploy-openshift.sh [-i SERVER_INSTANCES] [-g GALAXIES_IMAGE]`

- **SERVER_INSTANCES**: Number of galaxies instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **GALAXIES_IMAGE**: galaxies image to be used to deploy galaxies. It is optional, if is not specified then the default image `dinogun/galaxies:1.1-jdk-11.0.10_9` will be considered for the deployment.

**`$./scripts/galaxies-deploy-minikube.sh -i 2`** 

```
Removing the galaxies instances...done
servicemonitor.monitoring.coreos.com/galaxies-0 created
servicemonitor.monitoring.coreos.com/galaxies-1 created
deployment.apps/galaxies-sample-0 created
service/galaxies-service-0 created
deployment.apps/galaxies-sample-1 created
service/galaxies-service-1 created

```
# Openshift
To deploy the benchmark use `galaxies-deploy-openshift.sh`

`./scripts/galaxies-deploy-openshift.sh -s BENCHMARK_SERVER [-n NAMESPACE] [-i SERVER_INSTANCES] [-g GALAXIES_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM]`

- **BENCHMARK_SERVER**: Name of the cluster you are using
- **SERVER_INSTANCES**: Number of galaxies instances to be deployed. It is optional, if is not specified then by default it will be considered as 1 instance.
- **NAMESPACE**: Namespace in which galaxies application is to be deployed. It is optional, if not specified then `default` will be considered as the namespace. 
- **GALAXIES_IMAGE**: galaxies image to be used to deploy galaxies. It is optional, if is not specified then the default image `dinogun/galaxies:1.1-jdk-11.0.10_9` will be considered for the deployment.
- **CPU_REQ**: CPU request
- **MEM_REQ**: Memory request
- **CPU_LIM**: CPU limit
- **MEM_LIM**: Memory limit

Example to deploy and run galaxies application on openshift cluster

**`$./scripts/galaxies-deploy-openshift.sh -s rouging.os.fyre.ibm.com -n openshift-monitoring -i 2`**

```
Removing the galaxies instances...done
servicemonitor.monitoring.coreos.com/galaxies-0 created
servicemonitor.monitoring.coreos.com/galaxies-1 created
deployment.apps/galaxies-sample-0 created
service/galaxies-service-0 created
deployment.apps/galaxies-sample-1 created
service/galaxies-service-1 created
route.route.openshift.io/galaxies-service-0 exposed
route.route.openshift.io/galaxies-service-1 exposed

```

# Run the load
Simulating the load on galaxies benchmarks using hyperfoil/wrk
`./scripts/galaxies-load.sh -c CLUSTER_TYPE [-i SERVER_INSTANCES] [--iter MAX_LOOP] [-n NAMESPACE] [-a IP_ADDR] [-t THREAD] [-R REQUEST_RATE] [-d DURATION] [--connection=CONNECTIONS]`

- **CLUSTER_TYPE**: docker|minikube|openshift
- **SERVER_INSTANCES**: Number of galaxies instances to which you want to run the load.  It is optional, if is not specified then by default it will be considered as 1 instance. 
- **MAX_LOOP**: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.
- **NAMESPACE**: Namespace in which galaxies application is deployed(Required only in the case of openshift cluster and if the application is deployed in other namespaces except `openshift-monitoring`)
- **IP_ADDR**: IP address of the machine. It is optional, if it is not specified then the get_ip function written inside the script will get the IP address of the machine.
- **THREAD**: Number of threads
- **REQUEST_RATE**: Requests rate
- **DURATION**: Test duration
- **CONNECTIONS**: Number of connectionss

Example to run the load on 1 galaxies instances for 2 iterations in openshift cluster

**`$./scripts/galaxies-load.sh -c docker --iter=2`**
```
#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################

Running wrk load for galaxies instance 1 with the following parameters
CMD=./wrk2.sh --threads=10 --connections=700 --duration=60s --rate=2000 http://192.168.122.105:32000/galaxies
wrk logs Dir : /home/shruthi/galaxies-12-mar/benchmarks/galaxies/logs/galaxies-2021-03-12:12:30

#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################

Running wrk load for galaxies instance 1 with the following parameters
CMD=./wrk2.sh --threads=20 --connections=700 --duration=60s --rate=2000 http://192.168.122.105:32000/galaxies
wrk logs Dir : /home/shruthi/galaxies-12-mar/benchmarks/galaxies/logs/galaxies-2021-03-12:12:30
#########################################################################################
				Displaying the results					       
#########################################################################################
RUN, THROUGHPUT, RESPONSE_TIME, MAX_RESPONSE_TIME, STDDEV_RESPONSE_TIME, ERRORS
1,     2008.90,     1.31,         150.99,              4.40,               0
2,     2001.05,     939.76,       84.93,               1.84,               0

```
Above image shows the logs of the load run, it processes and displays the output for each run. See Displaying the results section of the log for information about throughput, Number of pages it has retreived, average response time and errors if any.

To run the load for multiple instances in case of openshift cluster follow [README.md](/galaxies/scripts/perf/README.md)

# Cleanup
`$ ./scripts/galaxies-cleanup.sh -c CLUSTER_TYPE[docker|minikube|openshift] [-n NAMESPACE]`

- **CLUSTER_TYPE**: docker|minikube|openshift
- **NAMESPACE**: Namespace in which galaxies application is deployed(Required only in the case of openshift cluster and if the application is deployed in other namespaces except `openshift-monitoring`). 

# Note for RHEL 8.0 users
podman docker should have the latest network version to work.












