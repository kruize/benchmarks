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
### Script to deploy the one or more instances of galaxies application on openshift###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/galaxies-common.sh

# Run the benchmark as
# SCRIPT BENCHMARK_SERVER 
# Ex of ARGS :  -s wobbled.os.fyre.ibm.com -i 2 -g dinogun/galaxies:1.1-jdk-11.0.10_9

CLUSTER_TYPE="openshift"

# Describes the usage of the script
function usage() {
	echo
	echo "Usage: $0 -s BENCHMARK_SERVER [-i SERVER_INSTANCES] [-n NAMESPACE] [-g GALAXIES_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] "
	echo " "
	echo "Example: $0 -s rouging.os.fyre.ibm.com  -i 2 -g dinogun/galaxies:1.1-jdk-11.0.10_9 --cpulim=4 --cpureq=2 --memlim=1024Mi --memreq=512Mi"
	exit -1
}

# Check if the memory request/limit has unit. If not ask user to append the unit
# input: Memory request/limit passed by user
# output: Check memory request/limit for unit , if not specified suggest the user to specify the unit
function check_memory_unit() {
	MEM=$1
	case "${MEM}" in
		[0-9]*M)
			;;
		[0-9]*Mi)
			;;
		[0-9]*K)
			;;
		[0-9]*Ki)
			;;
		[0-9]*G)
			;;
		[0-9]*Gi)
			;;
		*)
			echo "Error : Do specify the memory Unit"
			echo "Example: ${MEM}K/Ki/M/Mi/G/Gi"
			usage
			;;
	esac
}

# Iterate through the commandline options
while getopts s:i:g:n:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			cpureq=*)
				CPU_REQ=${OPTARG#*=}
				;;
			memreq=*)
				MEM_REQ=${OPTARG#*=}
				# check memory request for unit
				check_memory_unit ${MEM_REQ}
				;;
			cpulim=*)
				CPU_LIM=${OPTARG#*=}
				;;
			memlim=*)
				MEM_LIM=${OPTARG#*=}
				# check memory limit for unit
				check_memory_unit ${MEM_LIM}
				;;
			*)
		esac
		;;
	s)
		BENCHMARK_SERVER="${OPTARG}"
		;;
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	g)
		GALAXIES_IMAGE="${OPTARG}"		
		;;
	n)
		NAMESPACE="${OPTARG}"		
		;;
	esac
done

if [ -z "${BENCHMARK_SERVER}" ]; then
	echo "Do set the variable - BENCHMARK_SERVER "
	usage
	exit 1
fi

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${GALAXIES_IMAGE}" ]; then
	GALAXIES_IMAGE="${GALAXIES_DEFAULT_IMAGE}"
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="${DEFAULT_NAMESPACE}"
fi

# Create multiple yamls based on instances and Update the template yamls with names and create multiple files
# input:galaxies and service-monitor yaml file
function createInstances() {
	#Create the deployments and services
	#Using inmem DB so no DB specific pods

	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/name: galaxies/name: galaxies-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor.yaml > ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/galaxies-app/galaxies-app-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/galaxies-port/galaxies-port-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		oc create -f ${MANIFESTS_DIR}/service-monitor-${inst}.yaml -n ${NAMESPACE}
	done
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/galaxies-sample/galaxies-sample-'${inst}'/g' ${MANIFESTS_DIR}/galaxies.yaml > ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		sed -i "s|${GALAXIES_DEFAULT_IMAGE}|${GALAXIES_IMAGE}|g" ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		sed -i 's/galaxies-service/galaxies-service-'${inst}'/g' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		sed -i 's/galaxies-app/galaxies-app-'${inst}'/g' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		sed -i 's/galaxies-port/galaxies-port-'${inst}'/g' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
	
		# Setting cpu/mem request limits
		if [ ! -z  ${MEM_REQ} ]; then
			sed -i '/requests:/a \ \ \ \ \ \ \ \ \ \ memory: '${MEM_REQ}'' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		fi
		if [ ! -z  ${CPU_REQ} ]; then
			sed -i '/requests:/a \ \ \ \ \ \ \ \ \ \ cpu: '${CPU_REQ}'' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		fi
		if [ ! -z  ${MEM_LIM} ]; then
			sed -i '/limits:/a \ \ \ \ \ \ \ \ \ \ memory: '${MEM_LIM}'' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		fi
		if [ ! -z  ${CPU_LIM} ]; then
			sed -i '/limits:/a \ \ \ \ \ \ \ \ \ \ cpu: '${CPU_LIM}'' ${MANIFESTS_DIR}/galaxies-${inst}.yaml
		fi
		
		oc create -f ${MANIFESTS_DIR}/galaxies-${inst}.yaml -n ${NAMESPACE}
		err_exit "Error: Issue in deploying."
		((GALAXIES_PORT=GALAXIES_PORT+1))

	done

	#Wait till galaxies starts
	sleep 40

	#Expose the services
	svc_list=($(oc get svc --namespace=${NAMESPACE} | grep "service" | grep "galaxies" | cut -d " " -f1))
	for sv in "${svc_list[@]}"
	do
		oc expose svc/${sv} --namespace=${NAMESPACE}
		err_exit " Error: Issue in exposing service"
	done
	
	sleep 120
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

