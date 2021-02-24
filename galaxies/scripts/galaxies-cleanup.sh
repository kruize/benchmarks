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
### Script to remove the galaxies setup ###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/galaxies-common.sh

function usage() {
	echo
	echo "Usage: -c CLUSTER_TYPE[docker|minikube|openshift] [-n NAMESPACE]"
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

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

# Removes the galaxies instances from docker
# output: Stops the galaxies container and remove it, removes the network, Removes the galaxies and jmeter images if any
function remove_galaxies_docker() {
	galaxies_containers=$(docker ps | grep "galaxies-app" | cut -d " " -f1)
	for con in "${galaxies_containers[@]}"
	do
		if [ "${con}" ]; then
			# stop the galaxies container
			docker stop ${con}
			# remove the galaxies container
			docker rm ${con}
		fi
	done

	# remove the galaxies network
	docker network rm ${NETWORK}

	# remove the galaxies image if present
	if [[ "$(docker images -q ${GALAXIES_CUSTOM_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${GALAXIES_CUSTOM_IMAGE}
	fi
	
	if [[ "$(docker images -q ${GALAXIES_DEFAULT_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${GALAXIES_DEFAULT_IMAGE}
	fi
}

# Removes the galaxies instances from minikube
# output: Removes the galaxies deployments, services and service monitors
function remove_galaxies_minikube() {
	galaxies_deployments=($(kubectl get deployments  | grep "galaxies" | cut -d " " -f1))
	
	for de in "${galaxies_deployments[@]}"
	do
		kubectl delete deployment ${de}
	done

	#Delete the services and routes if any
	galaxies_services=($(kubectl get svc  | grep "galaxies" | cut -d " " -f1))
	for se in "${galaxies_services[@]}"
	do
		kubectl delete svc ${se}
	done
	
	galaxies_service_monitors=($(kubectl get servicemonitor | grep "galaxies" | cut -d " " -f1))
	for sm in "${galaxies_service_monitors[@]}"
	do
		kubectl delete servicemonitor ${sm}
	done
}

# Removes the galaxies instances from openshift
# output: Removes the galaxies deployments, services, service monitors and routes
function remove_galaxies_openshift() {
	galaxies_deployments=($(oc get deployments --namespace=${NAMESPACE} | grep "galaxies" | cut -d " " -f1))

	for de in "${galaxies_deployments[@]}"
	do
		oc delete deployment ${de} --namespace=${NAMESPACE}
	done

	#Delete the services and routes if any
	galaxies_services=($(oc get svc --namespace=${NAMESPACE} | grep "galaxies" | cut -d " " -f1))
	for se in "${galaxies_services[@]}"
	do
		oc delete svc ${se} --namespace=${NAMESPACE}
	done
	galaxies_routes=($(oc get route --namespace=${NAMESPACE} | grep "galaxies" | cut -d " " -f1))
	for ro in "${galaxies_routes[@]}"
	do
		oc delete route ${ro} --namespace=${NAMESPACE}
	done
	galaxies_service_monitors=($(oc get servicemonitor --namespace=${NAMESPACE} | grep "galaxies" | cut -d " " -f1))
	for sm in "${galaxies_service_monitors[@]}"
	do
		oc delete servicemonitor ${sm} --namespace=${NAMESPACE}
	done
}

echo -n "Removing the galaxies instances..."
remove_galaxies_${CLUSTER_TYPE} >> ${LOGFILE}
echo "done"
