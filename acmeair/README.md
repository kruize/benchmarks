# Instructions to run the acmeair application using scripts 
**The scripts written supports**
- [Docker](#Docker)
- [Minikube](#Minikube)
- [Openshift](#Openshift)

## Docker
Create the required setup
`/acmeair-setup.sh setup_info`

Builds the acmeair application from the scratch using the acmeair source files and creates the images required for the setup.

Example to build and run the acmeair application 

- **use_source_code**: Builds the acmeair application from the scratch by using the source code and creates the images required for the setup.
- **use_image**: Uses already built petclinic image 

Example to build and run the acmeair application from the scratch

**`$./acmeair-setup.sh setup_info use_source_code`**
```
Checking prereqs...done
Building acmeair application...done
Building acmeair driver...done
Building jmeter with acmeair driver...done
Running acmeair and mongo db...done

```
In case of `use_image` by default it uses `dinogun/acmeair-monolithic:latest` for acmeair application . If you want to use custom images then you need to mention it explicitly.

Example to run the petclinic application using built in image

**`./acmeair-setup.sh use_image shruthi07acharya/acmeair_mono_service_liberty:latest`**
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
`./acmeair-load.sh load_info`

**load_info**: [load type] [Number of iterations of the jmeter load] [ip_addr / namespace]"
- **load type**: docker icp openshift
- **Number of iterations of the jmeter load**: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.
- **ip_addr**: IP address of the machine. It is optional, if it is not specified then the get_ip function written inside the script will get the IP address of the machine.

`jmeter:3.1` is the image used to apply the load

Example to run the load on openshift cluster
```
  ./acmeair-load.sh openshift 2

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
`$ ./acmeair-cleanup.sh`

# Kruize
If you want to quickly size the petclinic application container using a test load, run the Kruize container locally and point it to petclinic application container to get recommendation. Kruize monitors the app container using Prometheus and provides recommendations as a Grafana dashboard (Prometheus and Grafana containers are automatically downloaded when you run kruize).

**Kruize Installation**

# Docker

**`$ ./scripts/kruize-setup.sh docker`**
```
Creating kruize setup...~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
done
Deploying kruize on docker ...~/benchmarks/spring-petclinic/kruize ~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic

###   Installing kruize for docker...


Info: Checking pre requisites for Docker...
...

Waiting for kruize container to come up
########################     Starting App Monitor loop    #########################
Kruize recommendations available on the grafana dashboard at: http://localhost:3000
Info: Press CTRL-C to exit
 cadvisor: found. Adding to list of containers to be monitored.
 grafana: found. Adding to list of containers to be monitored.
 kruize: found. Adding to list of containers to be monitored.
 prometheus: found. Adding to list of containers to be monitored.

```

Now edit `manifests/docker/kruize-docker.yaml` to add the petclinic container name that you need kruize to monitor.

```
$ cat manifests/docker/kruize-docker.yaml 
---
# Add names of the containers that you want kruize to monitor, one per line in double quotes
containers:
  - name: "cadvisor"
  - name: "grafana"
  - name: "kruize"
  - name: "prometheus"
  - name: "acmeair-mono-app1"
  - name: "acmeair-db1"
```

In the above example, kruize is monitoring the application containers `acmeair-mono-app1` and `acmeair-db1` as well as its own set of containers. You should now see the "App Monitor loop" listing the new containers to be monitored

```
 cadvisor: found. Adding to list of containers to be monitored.
 grafana: found. Adding to list of containers to be monitored.
 kruize: found. Adding to list of containers to be monitored.
 prometheus: found. Adding to list of containers to be monitored.
 acmeair-mono-app1: found. Adding to list of containers to be monitored.
 acmeair-db1: found. Adding to list of containers to be monitored.
```
# Minikube

**`$ ./scripts/kruize-setup.sh minikube`**
```
Creating kruize setup...~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
done
Deploying kruize on minikube ...~/benchmarks/spring-petclinic/kruize ~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic

###   Installing kruize for minikube


Info: Checking pre requisites for minikube...
Info: kruize needs cadvisor/prometheus/grafana to be installed in minikube
Download and install these software to minikube(y/n)? y                     <----- Say yes to install cadvisor/prometheus/grafana
Info: Downloading cadvisor git
...

Info: Downloading prometheus git

Info: Installing prometheus
...

Info: Waiting for all Prometheus Pods to get spawned......done
Info: Waiting for prometheus-k8s-1 to come up...
prometheus-k8s-1                      2/3     Running   0          5s
Info: prometheus-k8s-1 deploy succeeded: Running
prometheus-k8s-1                      2/3     Running   0          6s


Info: One time setup - Create a service account to deploy kruize
serviceaccount/kruize-sa created
clusterrole.rbac.authorization.k8s.io/kruize-cr created
clusterrolebinding.rbac.authorization.k8s.io/kruize-crb created
servicemonitor.monitoring.coreos.com/kruize created
prometheus.monitoring.coreos.com/prometheus created

Info: Deploying kruize yaml to minikube cluster
deployment.apps/kruize created
service/kruize created
Info: Waiting for kruize to come up...
kruize-695c998775-vv4dn               0/1     ContainerCreating   0          4s
kruize-695c998775-vv4dn               1/1     Running   0          9s
Info: kruize deploy succeeded: Running
kruize-695c998775-vv4dn               1/1     Running   0          9s

Info: Access grafana dashboard to see kruize recommendations at http://localhost:3000 <--- Click on this link to access grafana dashboards
Info: Run the following command first to access grafana port
      $ kubectl port-forward -n monitoring grafana-58dc7468d7-rn7nx 3000:3000		<---- But run this command first

```
# Openshift

**`$ ./scripts/kruize-setup.sh openshift`**
```
Creating kruize setup...~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
done
Deploying kruize on openshift ...~/benchmarks/spring-petclinic/kruize ~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic

###   Installing kruize for OpenShift

WARNING: This will create a Kruize ServiceMonitor object in the openshift-monitoring namespace
WARNING: This is currently not recommended for production

Create ServiceMonitor object and continue installation?(y/n)? y

Info: Checking pre requisites for OpenShift...done
Info: Logging in to OpenShift cluster...
Authentication required for https://aaa.bbb.com:6443 (openshift)
Username: kubeadmin
Password: 
Login successful.

You have access to 52 projects, the list has been suppressed. You can list all projects with 'oc projects'

Using project "kube-system".

Info: Setting Prometheus URL as https://prometheus-k8s-openshift-monitoring.apps.kaftans.os.fyre.ibm.com
Info: Deploying kruize yaml to OpenShift cluster
Now using project "openshift-monitoring" on server "https://api.kaftans.os.fyre.ibm.com:6443".
deployment.extensions/kruize configured
service/kruize unchanged
Info: Waiting for kruize to come up...
kruize-5cd5967d97-tz2cb                        0/1     ContainerCreating   0          6s
kruize-5cd5967d97-tz2cb                        0/1     ContainerCreating   0          13s
kruize-5cd5967d97-tz2cb                        1/1     Running   0          20s
Info: kruize deploy succeeded: Running
kruize-5cd5967d97-tz2cb                        1/1     Running   0          24s
```

# Note for RHEL 8.0 users
podman docker should have the latest network version to work.












