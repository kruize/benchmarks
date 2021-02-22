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
### Script to remove the acmeair setup ###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/acmeair-common.sh

function usage() {
	echo
	echo "Usage: -c CLUSTER_TYPE[docker|minikube|openshift] [-n NAMESPACE]"
	exit -1
}

while getopts c:n:-: gopts
do
	case ${gopts} in
	c)
		CLUSTER_TYPE=${OPTARG}
		;;
	n)
		NAMESPACE="${OPTARG}"		
		;;
	esac
done

if [ -z "${CLUSTER_TYPE}" ]; then
	usage
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="${DEFAULT_NAMESPACE}"
fi

# Removes the acmeair and mongo db instances from docker
# output: Stops the acmeair and mongodb container and remove it, removes the network, Removes the acmeair and jmeter images if any
function remove_acmeair_docker() {
	# Stop the acmeair containers and remove it
	acmeair_containers=$(docker ps | grep "acmeair-mono-app" | cut -d " " -f1)
	for con in "${acmeair_containers[@]}"
	do
		if [ "${con}" ]; then
			# stop the acmeair container
			docker stop ${con}
			# remove the acmeair container
			docker rm ${con}
		fi
	done
	
	# Stop the mongo db containers and remove it
	mongodb_containers=$(docker ps | grep "acmeair-db" | cut -d " " -f1)
	for dbcon in "${mongodb_containers[@]}"
	do
		if [ "${dbcon}" ]; then
			# stop the mongo db container
			docker stop ${dbcon}
			# remove the mongo db container
			docker rm ${dbcon}
		fi
	done

	# Clean acmeair monolithic application docker image
	pushd acmeair
	# Build the application
	docker run --rm -v "${PWD}":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle clean
	popd

	# Clean acmeair driver
	pushd jmeter-driver
	docker run --rm -v "${PWD}":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle clean
	popd

	docker network rm ${NETWORK}

	if [[ "$(docker images -q ${ACMEAIR_CUSTOM_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${ACMEAIR_CUSTOM_IMAGE}
	fi

	if [[ "$(docker images -q ${ACMEAIR_CUSTOM_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${ACMEAIR_CUSTOM_IMAGE}
	fi
	
	if [[ "$(docker images -q ${JMETER_CUSTOM_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${JMETER_CUSTOM_IMAGE}
	fi
	
	if [[ "$(docker images -q ${JMETER_DEFAULT_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${JMETER_DEFAULT_IMAGE}
	fi
}

# Removes the acmeair instances from minikube
# output: Removes the acmeair deployments, services and service monitors
function remove_acmeair_minikube() {
	acmeair_deployments=($(kubectl get deployments  | grep "acmeair" | cut -d " " -f1))
	
	for de in "${acmeair_deployments[@]}"	
	do
		kubectl delete deployment ${de} 
	done

	#Delete the services and routes if any
	acmeair_services=($(kubectl get svc  | grep "acmeair" | cut -d " " -f1))
	for se in "${acmeair_services[@]}"
	do
		kubectl delete svc ${se} 
	done	
}

# Removes the acmeair instances from openshift
# output: Removes the acmeair deployments, services, service monitors and routes
function remove_acmeair_openshift() {
	acmeair_deployments=($(oc get deployments --namespace=${NAMESPACE} | grep "acmeair" | cut -d " " -f1))
	for de in "${acmeair_deployments[@]}"
	do
		oc delete deployment ${de} --namespace=${NAMESPACE}
	done

	#Delete the services and routes if any
	acmeair_services=($(oc get svc --namespace=${NAMESPACE} | grep "acmeair" | cut -d " " -f1))
	for se in "${acmeair_services[@]}"
	do
		oc delete svc ${se} --namespace=${NAMESPACE}
	done
	acmeair_routes=($(oc get route --namespace=${NAMESPACE} | grep "acmeair" | cut -d " " -f1))
	for ro in "${acmeair_routes[@]}"
	do
		oc delete route ${ro} --namespace=${NAMESPACE}
	done
}

echo -n "Removing the acmeair instances... "
echo
remove_acmeair_${CLUSTER_TYPE}
echo "done"

