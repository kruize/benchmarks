# Instructions to run the petclinic application using scripts 

# Docker
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
 
In case of `use_image` by default it uses `kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.20.0` for petclinic application and `kruize/jmeter_petclinic:3.1` for jmeter. If you want to use custom images then you need to mention it explicitly.

Example to run the petclinic application using built in image

**`$./scripts/petclinic-setup.sh use_image kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.20.0 kruize/jmeter_petclinic:3.1`**
```
Checking prereqs...done
Pulling the jmeter image...done
Running petclinic with inbuilt db...done

```
# Minikube
To deploy the benchmark use `petclinic-deploy-minikube.sh`

`./scripts/petclinic-deploy-openshift.sh Manifest_dir`

**Manifest_dir**: Path where the manifest directory exists

**`$./scripts/petclinic-deploy-minikube.sh manifests/`** 
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
deployment.apps/petclinic-sample-0 created
service/petclinic-service-0 created

```
# Openshift
To deploy the benchmark use `petclinic-deploy-openshift.sh`

`./scripts/petclinic-deploy-openshift.sh deploy_info`

**deploy_info**: Benchmark server , Namespace , Manifests directory and Results directory path

- **Benchmark server**: Name of the cluster you are using
- **Namespace**: openshift-monitoring
- **Manifests directory**: Path where the manifest directory exists
- **Results directory path**: Location where you want to store the results

**`$./scripts/petclinic-deploy-openshift.sh rouging.os.fyre.ibm.com openshift-monitoring manifests/ result/`**
```
~/benchmarks/spring-petclinic ~/benchmarks/spring-petclinic
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
  - name: "petclinic-app"
```

In the above example, kruize is monitoring the petclinic application container `petclinic-app`. You should now see the "App Monitor loop" listing the new containers to be monitored

```
 cadvisor: found. Adding to list of containers to be monitored.
 grafana: found. Adding to list of containers to be monitored.
 kruize: found. Adding to list of containers to be monitored.
 prometheus: found. Adding to list of containers to be monitored.
 petclinic-app: found. Adding to list of containers to be monitored.
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
**Kruize Recommendation**

Example to get the kruize recommendation for petclinic application on docker 
**`$./scripts/kruize-recommendation.sh docker`**
```
#############################################################

              kruize recommendation for petclinic..
#############################################################

[
  {
    "application_name": "petclinic-app",
    "resources": {
      "requests": {
        "memory": "418.7M",
        "cpu": 1.1
      },
      "limits": {
        "memory": "502.4M",
        "cpu": 1.2
      }
    }
  }
]

```

# Note for RHEL 8.0 users
podman docker should have the latest network version to work.














