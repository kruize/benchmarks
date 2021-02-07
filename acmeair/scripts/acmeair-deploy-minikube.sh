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
### Script to deploy the acmeair application on minikube ###
#
# Run the benchmark as
# SCRIPT SERVER_INSTANCES ACMEAIR_IMAGE
# Ex of ARGS : -i 2 -a dinogun/acmeair-monolithic   

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/acmeair-common.sh
CLUSTER_TYPE="minikube"

# Iterate through the commandline options
while getopts i:a:-: gopts
do
	case ${gopts} in
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	a)
		ACMEAIR_IMAGE="${OPTARG}"
		;;
	esac
done

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${ACMEAIR_IMAGE}" ]; then
	ACMEAIR_IMAGE="${ACMEAIR_DEFAULT_IMAGE}"
fi

# Deploy the mongo db and acmeair application
function createInstances() {
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/acmeair-db/acmeair-db-'${inst}'/g' ${MANIFESTS_DIR}/mongo-db.yaml > ${MANIFESTS_DIR}/mongo-db-${inst}.yaml
		kubectl create -f ${MANIFESTS_DIR}/mongo-db-${inst}.yaml 
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
		kubectl create -f ${MANIFESTS_DIR}/acmeair-${inst}.yaml 
		err_exit "Error: Issue in deploying."
		((ACMEAIR_PORT=ACMEAIR_PORT+1))
	done

	#Wait till acmeair starts
	sleep 120
	
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
