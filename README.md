# Kruize
If you want to quickly size the petclinic application container using a test load, run the Kruize container locally and point it to petclinic application container to get recommendation. Kruize monitors the app container using Prometheus and provides recommendations as a Grafana dashboard (Prometheus and Grafana containers are automatically downloaded when you run kruize).

**kruize supports**
- Docker
- Minikube
- Openshift

**Installation**

Create required setup and deploy kruize on different environments(docker,minikube and openshift)

`$ ./scripts/kruize-setup.sh [docker|minikube|openshift]` 

## Docker

**`$ ./scripts/kruize-setup.sh docker`**

Edit `manifests/docker/kruize-docker.yaml` to add the application container name that you need kruize to monitor.

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

**Kruize Recommendation**
`$./scripts/kruize-recommendation.sh cluster_type App_name`

- **cluster_type:** docker|minikube|openshift
- **App_name:** application name for which you want to get the kruize recommendation 

Example to get the kruize recommendation for petclinic application on docker 
**`$./scripts/kruize-recommendation.sh docker petclinic`**
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
