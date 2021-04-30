#!/bin/bash
#
# Copyright (c) 2020, 2021 Red Hat, IBM Corporation and others.
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
### Script to deploy the one or more instances of galaxies application on minikube###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/galaxies-common.sh
 
# Run the benchmark as
# SCRIPT  MANIFESTS_DIR 
# Ex of ARGS :  -i 2 -g dinogun/galaxies:1.1-jdk-11.0.10_9 

CLUSTER_TYPE="minikube"

# Iterate through the commandline options
while getopts i:g:-: gopts
do
	case ${gopts} in
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	g)
		GALAXIES_IMAGE="${OPTARG}"		
		;;
	esac
done

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${GALAXIES_IMAGE}" ]; then
	GALAXIES_IMAGE="${GALAXIES_DEFAULT_IMAGE}"
fi

# Deploy the service monitor and galaxies application
# input:galaxies and service-monitor yaml file
function createInstances() {
	# Deploy service monitor to get Java Heap recommendations from galaxies$
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/name: galaxies/name: galaxies-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor.yaml > ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/galaxies-app/galaxies-app-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/galaxies-port/galaxies-port-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		kubectl create -f ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
	done
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/galaxies-sample/galaxies-sample-'${inst}'/g' ${MANIFESTS_DIR}/galaxies.yaml > $MANIFESTS_DIR/galaxies-${inst}.yaml
		sed -i "s|${GALAXIES_DEFAULT_IMAGE}|${GALAXIES_IMAGE}|g" ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		sed -i 's/galaxies-service/galaxies-service-'${inst}'/g' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		sed -i 's/galaxies-app/galaxies-app-'${inst}'/g' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		sed -i 's/galaxies-port/galaxies-port-'${inst}'/g' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		
		#Create the deployments and services
		kubectl create -f ${MANIFESTS_DIR}/galaxies-${inst}.yaml 
		err_exit "Error: Issue in deploying."
		((GALAXIES_PORT=GALAXIES_PORT+1))
	done
	#Wait till galaxies starts
	sleep 60
	
	# Check if the application is running
	check_app
}

# Delete the galaxies deployments,services and routes if it is already present 
function stopAllInstances() {
	${GALAXIES_REPO}/galaxies-cleanup.sh -c ${CLUSTER_TYPE}
}

# Stop all galaxies related instances if there are any
stopAllInstances
# Deploying instances
createInstances ${SERVER_INSTANCES}
