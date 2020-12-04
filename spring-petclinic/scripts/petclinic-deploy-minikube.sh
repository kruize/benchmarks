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

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/petclinic-common.sh
 
# Run the benchmark as
# SCRIPT  MANIFESTS_DIR 
# Ex of ARGS :  -i 2 -p kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0  

CLUSTER_TYPE="minikube"

# Iterate through the commandline options
while getopts i:p:-: gopts
do
	case ${gopts} in
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	p)
		PETCLINIC_IMAGE="${OPTARG}"		
		;;
	esac
done

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${PETCLINIC_IMAGE}" ]; then
	PETCLINIC_IMAGE="${PETCLINIC_DEFAULT_IMAGE}"
fi

# set the container port based on petclinic image
set_port ${PETCLINIC_IMAGE}

# Deploy the service monitor and petclinic application
# input:petclinic and service-monitor yaml file
function createInstances() {
	# Deploy service monitor to get Java Heap recommendations from petclinic$
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/name: petclinic/name: petclinic-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor.yaml > ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/petclinic-app/petclinic-app-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/petclinic-port/petclinic-port-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		kubectl create -f ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
	done
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/petclinic-sample/petclinic-sample-'${inst}'/g' ${MANIFESTS_DIR}/petclinic.yaml > $MANIFESTS_DIR/petclinic-${inst}.yaml
		sed -i "s|${PETCLINIC_DEFAULT_IMAGE}|${PETCLINIC_IMAGE}|g" ${MANIFESTS_DIR}/petclinic-${inst}.yaml
		sed -i 's/8081/'${PORT}'/g' ${MANIFESTS_DIR}/petclinic-${inst}.yaml
		sed -i 's/petclinic-service/petclinic-service-'${inst}'/g' ${MANIFESTS_DIR}/petclinic-${inst}.yaml
		sed -i 's/petclinic-app/petclinic-app-'${inst}'/g' ${MANIFESTS_DIR}/petclinic-${inst}.yaml
		sed -i 's/petclinic-port/petclinic-port-'${inst}'/g' ${MANIFESTS_DIR}/petclinic-${inst}.yaml
		sed -i 's/32334/'${PETCLINIC_PORT}'/g' ${MANIFESTS_DIR}/petclinic-${inst}.yaml
		#Create the deployments and services
		kubectl create -f ${MANIFESTS_DIR}/petclinic-${inst}.yaml 
		err_exit "Error: Issue in deploying."
		((PETCLINIC_PORT=PETCLINIC_PORT+1))
	done
	#Wait till petclinic starts
	sleep 120
	
	# Check if the application is running
	check_app
}

# Delete the petclinic deployments,services and routes if it is already present 
function stopAllInstances() {
	${PETCLINIC_REPO}/petclinic-cleanup.sh ${CLUSTER_TYPE}
}

# Stop all petclinic related instances if there are any
stopAllInstances
# Deploying instances
createInstances ${SERVER_INSTANCES}
