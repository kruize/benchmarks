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
### Script containing common functions ###

CURRENT_DIR="$(dirname "$(realpath "$0")")"
pushd "${CURRENT_DIR}" >> setup.log
pushd ".." >> setup.log

# Set the defaults for the app
export GALAXIES_PORT="32000"
export NETWORK="kruize-network"
LOGFILE="${PWD}/setup.log"
GALAXIES_REPO="${CURRENT_DIR}"
GALAXIES_DEFAULT_IMAGE="dinogun/galaxies:1.1-jdk-11.0.10_9"
GALAXIES_CUSTOM_IMAGE="galaxies:latest"
DEFAULT_NAMESPACE="openshift-monitoring"
MANIFESTS_DIR="manifests/"

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo
		echo "See ${LOGFILE} for more details"
		exit -1
	fi
}

# Check for all the prereqs
function check_prereq() {
	docker version > ${LOGFILE} 2>&1
	err_exit "Error: docker not installed \nInstall docker and try again."
}

# Get the IP addr of the machine / vm that we are running on
function get_ip() {
	IP_ADDR=$(ip addr | grep "global" | grep "dynamic" | awk '{ print $2 }' | cut -f 1 -d '/')
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(ip addr | grep "global" | head -1 | awk '{ print $2 }' | cut -f 1 -d '/')
	fi
}

# Check if the application is running
# output: Returns 1 if the application is running else returns 0
function check_app() {
	if [ "${CLUSTER_TYPE}" == "minikube" ]; then
		CMD=$(kubectl get pods | grep "galaxies" | grep "Running" | cut -d " " -f1)
	elif [ "${CLUSTER_TYPE}" == "openshift" ]; then
		CMD=$(oc get pods --namespace=${NAMESPACE} | grep "galaxies" | grep "Running" | cut -d " " -f1)
	else
		CMD=$(docker ps | grep "galaxies-app" | cut -d " " -f1)
	fi
	for status in "${CMD[@]}"
	do
		if [ -z "${status}" ]; then
			echo "Application pod did not come up" 
			exit -1;
		fi
	done
}

# Build the galaxies application
# input:base_image 
# output:build the application from scratch and create the galaxies docker image with the specified base_image(input)
function build_galaxies() {
	# Build the galaxies docker image
	docker build -t ${GALAXIES_CUSTOM_IMAGE} . >>${LOGFILE} 2>&1
	err_exit "Error: Building of docker image of galaxies."
}

# Run the galaxies application 
# input:galaxies image to be used and JVM arguments if any
# output:Create network bridge "kruize-network" and run galaxies application container on the same network
function run_galaxies() {
	GALAXIES_IMAGE=$1 
	INST=$2
	
	# Create docker network bridge "kruize-network"
	NET_NAME=`docker network ls -f "name=${NETWORK}" --format {{.Name}} | tail -n 1`
	echo
	if [[ -z ${NET_NAME} ]];  then
		echo "Creating Kruize network: ${NETWORK}..."
		docker network create --driver bridge ${NETWORK} 2>>${LOGFILE} >>${LOGFILE}
	else
		echo "${NETWORK} already exists..." 
	fi

	# Run the galaxies app container on "kruize-network"
	cmd="docker run -d --name=galaxies-app-${INST} -p ${GALAXIES_PORT}:8080 --network=${NETWORK} ${GALAXIES_IMAGE} "
	${cmd}s 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start galaxies container"
	((GALAXIES_PORT=GALAXIES_PORT+1))
	# Check if the application is running
	check_app
}
