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
### Script to deploy the one or more instances of petclinic application on openshift###
#

ROOT_DIR=.
pushd ${ROOT_DIR}
# Run the benchmark as
# SCRIPT BENCHMARK_SERVER NAMESPACE MANIFESTS_DIR RESULTS_DIR_PATH
# Ex of ARGS :  wobbled.os.fyre.ibm.com 2 kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0

BENCHMARK_SERVER=$1
SERVER_INSTANCES=$2
PETCLINIC_IMAGE=$3
NAMESPACE="openshift-monitoring"
MANIFESTS_DIR="${HOME}/benchmarks/spring-petclinic/manifests/"
DEFAULT_IMAGE="kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0"

CPU_REQ=$4
MEM_REQ=$5
CPU_LIM=$6
MEM_LIM=$7

if [ -z $BENCHMARK_SERVER ]; then
	echo "Do set the variable - BENCHMARK_SERVER  "
	exit 1
fi

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${PETCLINIC_IMAGE}" ]; then
	PETCLINIC_IMAGE="${DEFAULT_IMAGE}"
fi

if [[ "${PETCLINIC_IMAGE}" == "kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0"  || "${PETCLINIC_IMAGE}" == "spring-petclinic:latest" ]]; then
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

# Create multiple yamls based on instances and Update the template yamls with names and create multiple files
# input:petclinic and service-monitor yaml file
function createInstances() {
	#Create the deployments and services
	#Using inmem DB so no DB specific pods

	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/name: petclinic/name: petclinic-'$inst'/g' $MANIFESTS_DIR/service-monitor.yaml > $MANIFESTS_DIR/service-monitor-$inst.yaml
		sed -i 's/petclinic-app/petclinic-app-'$inst'/g' $MANIFESTS_DIR/service-monitor-$inst.yaml
		sed -i 's/petclinic-port/petclinic-port-'$inst'/g' $MANIFESTS_DIR/service-monitor-$inst.yaml
		oc create -f $MANIFESTS_DIR/service-monitor-$inst.yaml -n $NAMESPACE
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
		
		# Setting cpu/mem request limits
		if [ ! -z  ${CPU_REQ} ]; then
			sed -i '31 s/^/          cpu: '$CPU_REQ'\n          memory: '$MEM_REQ'\n/' $MANIFESTS_DIR/petclinic-$inst.yaml
			sed -i '34 s/^/          cpu: '$CPU_LIM'\n          memory: '$MEM_LIM'\n/' $MANIFESTS_DIR/petclinic-$inst.yaml
		fi
		oc create -f $MANIFESTS_DIR/petclinic-$inst.yaml -n $NAMESPACE
		err_exit "Error: Issue in deploying."
		((port=port+1))

	done

	#Wait till petclinic starts
	sleep 40
	#Expose the services
	svc_list=($(oc get svc --namespace=$NAMESPACE | grep "service" | grep "petclinic" | cut -d " " -f1))
	for sv in "${svc_list[@]}"
	do
		oc expose svc/$sv --namespace=$NAMESPACE
		err_exit " Error: Issue in exposing service"
	done
}

# Delete the petclinic deployments,services and routes if it is already present 
function stopAllInstances() {
	# Delete the deployments first to avoid creating replica pods
	petclinic_deployments=($(oc get deployments --namespace=$NAMESPACE | grep "petclinic" | cut -d " " -f1))

	for de in "${petclinic_deployments[@]}"
	do
		oc delete deployment $de --namespace=$NAMESPACE
	done

	#Delete the services and routes if any
	petclinic_services=($(oc get services --namespace=$NAMESPACE | grep "petclinic" | cut -d " " -f1))
	for se in "${petclinic_services[@]}"
	do
		oc delete service $se --namespace=$NAMESPACE
	done
	petclinic_routes=($(oc get route --namespace=$NAMESPACE | grep "petclinic" | cut -d " " -f1))
	for ro in "${petclinic_routes[@]}"
	do
		oc delete route $ro --namespace=$NAMESPACE
	done
	petclinic_service_monitors=($(oc get servicemonitor --namespace=$NAMESPACE | grep "petclinic" | cut -d " " -f1))
	for sm in "${petclinic_service_monitors[@]}"
	do
		oc delete servicemonitor $sm --namespace=$NAMESPACE
	done
}

# Stop all petclinic related instances if there are any
stopAllInstances
# Deploying instances
createInstances $SERVER_INSTANCES
