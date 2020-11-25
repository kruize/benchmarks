#!/bin/bash
#
# Copyright (c) 2020, 2020 IBM Corporation, RedHat and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
### Script to deploy the one or more instances of petclinic application on minikube###
#

ROOT_DIR=.
pushd ${ROOT_DIR} 
# Run the benchmark as
# SCRIPT  MANIFESTS_DIR 
# Ex of ARGS :  2 kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0  

LOGFILE="${ROOT_DIR}/setup.log"
SERVER_INSTANCES=$1
PETCLINIC_IMAGE=$2
MANIFESTS_DIR="${HOME}/benchmarks/spring-petclinic/manifests/"
DEFAULT_IMAGE="kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0"


if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${PETCLINIC_IMAGE}" ]; then
	PETCLINIC_IMAGE="${DEFAULT_IMAGE}"
fi

if [[ "${PETCLINIC_IMAGE}" == "kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0" || "${PETCLINIC_IMAGE}" == "spring-petclinic:latest" ]]; then
	PORT=8081
else
	PORT=8080
fi

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo "See ${LOGFILE} for more details"
		exit -1
	fi
}

# Deploy the service monitor and petclinic application
# input:petclinic and service-monitor yaml file
function createInstances() {
	# Deploy service monitor to get Java Heap recommendations from petclinic$
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/name: petclinic/name: petclinic-'$inst'/g' $MANIFESTS_DIR/service-monitor.yaml > $MANIFESTS_DIR/service-monitor-$inst.yaml
		sed -i 's/petclinic-app/petclinic-app-'$inst'/g' $MANIFESTS_DIR/service-monitor-$inst.yaml
		sed -i 's/petclinic-port/petclinic-port-'$inst'/g' $MANIFESTS_DIR/service-monitor-$inst.yaml
		kubectl apply -f $MANIFESTS_DIR/service-monitor-$inst.yaml
	done
	port=32334
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/petclinic-sample/petclinic-sample-'$inst'/g' $MANIFESTS_DIR/petclinic.yaml > $MANIFESTS_DIR/petclinic-$inst.yaml
		sed -i "s|${DEFAULT_IMAGE}|${PETCLINIC_IMAGE}|g" $MANIFESTS_DIR/petclinic-$inst.yaml
		sed -i 's/8081/'$PORT'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
		sed -i 's/petclinic-service/petclinic-service-'$inst'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
		sed -i 's/petclinic-app/petclinic-app-'$inst'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
		sed -i 's/petclinic-port/petclinic-port-'$inst'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
		sed -i 's/32334/'$port'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
		#Create the deployments and services
		kubectl apply -f $MANIFESTS_DIR/petclinic-$inst.yaml 
		err_exit "Error: Issue in deploying."
		((port=port+1))
	done
	#Wait till petclinic starts
	sleep 40
}

# Delete the petclinic deployment,service and route if it is already present 
function stopAllInstances() {
	# Delete the deployments first to avoid creating replica pods
	petclinic_deployments=($(kubectl get deployments  | grep "petclinic" | cut -d " " -f1))
	
	for de in "${petclinic_deployments[@]}"	
	do
		kubectl delete deployment $de 
	done

	#Delete the services and routes if any
	petclinic_services=($(kubectl get services  | grep "petclinic" | cut -d " " -f1))
	for se in "${petclinic_services[@]}"
	do
		kubectl delete service $se 
	done	
}

# Stop all petclinic related instances if there are any
stopAllInstances
# Deploying instances
createInstances $SERVER_INSTANCES
