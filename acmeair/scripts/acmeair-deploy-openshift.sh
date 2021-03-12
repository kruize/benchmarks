#!/bin/bash
#
# Copyright (c) 2020, 2021 IBM Corporation, RedHat and others.
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
### Script to deploy the one or more instances of acmeair application on openshift ###
#
# Run the benchmark as
# SCRIPT BENCHMARK_SERVER NAMESPACE RESULTS_DIR_PATH SERVER_INSTANCES
# Ex of ARGS :  -s wobbled.os.fyre.ibm.com default -n openshift-monitoring -i 2 


CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/acmeair-common.sh
CLUSTER_TYPE="openshift"

# Describes the usage of the script
function usage() {
	echo
	echo "Usage: $0 -s BENCHMARK_SERVER [-n NAMESPACE] [-i SERVER_INSTANCES] [-a ACMEAIR_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] [--env=ENV_VAR]"
	echo " "
	echo "Example: $0 -s rouging.os.fyre.ibm.com  -i 2 -a dinogun/acmeair-monolithic:latest --cpulim=4 --cpureq=2 --memlim=1024Mi --memreq=512Mi"
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
while getopts s:i:a:n:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			cpureq=*)
				CPU_REQ=${OPTARG#*=}
				;;
			memreq=*)
				MEM_REQ=${OPTARG#*=}
				;;
			cpulim=*)
				CPU_LIM=${OPTARG#*=}
				;;
			memlim=*)
				MEM_LIM=${OPTARG#*=}
				;;
			env=*)
				ENV_VAR=${OPTARG#*=}
				;;
			*)
		esac
		;;
	s)
		BENCHMARK_SERVER=${OPTARG}
		;;
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	a)
		ACMEAIR_IMAGE="${OPTARG}"		
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

if [ -z "${ACMEAIR_IMAGE}" ]; then
	ACMEAIR_IMAGE="${ACMEAIR_DEFAULT_IMAGE}"
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="${DEFAULT_NAMESPACE}"
fi

# check memory limit for unit
if [ ! -z "${MEM_LIM}" ]; then
	check_memory_unit ${MEM_LIM}
fi

# check memory request for unit
if [ ! -z "${MEM_REQ}" ]; then
	check_memory_unit ${MEM_REQ}
fi

# Deploy the mongo db and acmeair application
function createInstances() {
	# Create multiple yamls based on instances and Update the template yamls with names and create multiple files
	# #Create the deployments and services
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/acmeair-db/acmeair-db-'${inst}'/g' ${MANIFESTS_DIR}/mongo-db.yaml > ${MANIFESTS_DIR}/mongo-db-${inst}.yaml
		oc create -f ${MANIFESTS_DIR}/mongo-db-${inst}.yaml -n ${NAMESPACE}
		err_exit "Error: Issue in deploying."
		((DB_PORT=DB_PORT+1))
	done
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/acmeair-sample/acmeair-sample-'${inst}'/g' ${MANIFESTS_DIR}/acmeair.yaml > ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		sed -i 's/acmeair-deployment/acmeair-deployment-'${inst}'/g' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		sed -i "s|${ACMEAIR_DEFAULT_IMAGE}|${ACMEAIR_IMAGE}|g" ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		sed -i 's/acmeair-service/acmeair-service-'${inst}'/g' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		sed -i 's/acmeair-app/acmeair-app-'${inst}'/g' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		sed -i 's/acmeair-db/acmeair-db-'${inst}'/g' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		sed -i 's/32221/'${ACMEAIR_PORT}'/g' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		
		# Setting cpu/mem request limits
		if [ ! -z  ${MEM_REQ} ]; then
			sed -i '/requests:/a \ \ \ \ \ \ \ \ \ \ memory: '${MEM_REQ}'' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		fi
		if [ ! -z  ${CPU_REQ} ]; then
			sed -i '/requests:/a \ \ \ \ \ \ \ \ \ \ cpu: '${CPU_REQ}'' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		fi
		if [ ! -z  ${MEM_LIM} ]; then
			sed -i '/limits:/a \ \ \ \ \ \ \ \ \ \ memory: '${MEM_LIM}'' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		fi
		if [ ! -z  ${CPU_LIM} ]; then
			sed -i '/limits:/a \ \ \ \ \ \ \ \ \ \ cpu: '${CPU_LIM}'' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		fi
		
		# Pass environment variables
		if [ ! -z  ${ENV_VAR} ]; then
			sed -i '/env:/a \ \ \ \ \ \ \ \ - name: "JVM_ARGS"' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
			sed -i '/- name: "JVM_ARGS"/a \ \ \ \ \ \ \ \ \ \ value: '${ENV_VAR}'' ${MANIFESTS_DIR}/acmeair-${inst}.yaml
		fi
		
		oc create -f ${MANIFESTS_DIR}/acmeair-${inst}.yaml -n ${NAMESPACE}
		err_exit "Error: Issue in deploying."
		((ACMEAIR_PORT=ACMEAIR_PORT+1))
	done
	
	#Wait till acmeair starts
	sleep 40
	#Expose the services
	svc_list=($(oc get svc --namespace=${NAMESPACE} | grep "service" | grep "acmeair" | cut -d " " -f1))
	for sv in "${svc_list[@]}"
	do
		oc expose svc/${sv} --namespace=${NAMESPACE}
		err_exit " Error: Issue in exposing service"
	done
	
	sleep 60 
	# Check if the application is running
	check_app
}

# Delete the acmeair deployments,services and routes if it is already present
function stopAllInstances() { 
	# Delete the deployments first to avoid creating replica pods
	${ACMEAIR_REPO}/acmeair-cleanup.sh -c ${CLUSTER_TYPE}
}

# Stop all acmeair related instances if there are any
stopAllInstances
# Deploying instances
createInstances ${SERVER_INSTANCES}
