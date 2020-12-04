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
### Script to remove the petclinic setup ###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/petclinic-common.sh

function usage() {
	echo
	echo "Usage: cluster_type [docker|minikube|openshift]"
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

CLUSTER_TYPE=$1
NAMESPACE="openshift-monitoring"

# Removes the petclinic instances from docker
# output: Stops the petclinic container and remove it, removes the network, Removes the petclinic and jmeter images if any
function remove_petclinic_docker() {
	petclinic_containers=$(docker ps | grep "petclinic-app" | cut -d " " -f1)
	for con in "${petclinic_containers[@]}"
	do
		if [ ${con} ]; then
			# stop the petclinic container
			docker stop ${con}
			# remove the petclinic container
			docker rm ${con}
		fi
	done

	# remove the petclinic network
	docker network rm ${NETWORK}

	# remove the petclinic image if present
	if [[ "$(docker images -q ${PETCLINIC_CUSTOM_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${PETCLINIC_CUSTOM_IMAGE}
	fi
	
	if [[ "$(docker images -q ${PETCLINIC_DEFAULT_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${PETCLINIC_DEFAULT_IMAGE}
	fi
	
	# remove the jmeter image if present
	if [[ "$(docker images -q ${JMETER_CUSTOM_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${JMETER_CUSTOM_IMAGE}
	fi
	
	if [[ "$(docker images -q ${JMETER_DEFAULT_IMAGE} 2> /dev/null)" != "" ]]; then
		docker rmi ${JMETER_DEFAULT_IMAGE}
	fi
}

# Removes the petclinic instances from minikube
# output: Removes the petclinic deployments, services and service monitors
function remove_petclinic_minikube() {
	petclinic_deployments=($(kubectl get deployments  | grep "petclinic" | cut -d " " -f1))
	
	for de in "${petclinic_deployments[@]}"	
	do
		kubectl delete deployment ${de} 
	done

	#Delete the services and routes if any
	petclinic_services=($(kubectl get svc  | grep "petclinic" | cut -d " " -f1))
	for se in "${petclinic_services[@]}"
	do
		kubectl delete svc ${se} 
	done	
	
	petclinic_service_monitors=($(kubectl get servicemonitor | grep "petclinic" | cut -d " " -f1))
	for sm in "${petclinic_service_monitors[@]}"
	do
		kubectl delete servicemonitor ${sm} 
	done
}

# Removes the petclinic instances from openshift
# output: Removes the petclinic deployments, services, service monitors and routes
function remove_petclinic_openshift() {
	petclinic_deployments=($(oc get deployments --namespace=${NAMESPACE} | grep "petclinic" | cut -d " " -f1))

	for de in "${petclinic_deployments[@]}"
	do
		oc delete deployment ${de} --namespace=${NAMESPACE}
	done

	#Delete the services and routes if any
	petclinic_services=($(oc get svc --namespace=${NAMESPACE} | grep "petclinic" | cut -d " " -f1))
	for se in "${petclinic_services[@]}"
	do
		oc delete svc ${se} --namespace=${NAMESPACE}
	done
	petclinic_routes=($(oc get route --namespace=${NAMESPACE} | grep "petclinic" | cut -d " " -f1))
	for ro in "${petclinic_routes[@]}"
	do
		oc delete route ${ro} --namespace=${NAMESPACE}
	done
	petclinic_service_monitors=($(oc get servicemonitor --namespace=${NAMESPACE} | grep "petclinic" | cut -d " " -f1))
	for sm in "${petclinic_service_monitors[@]}"
	do
		oc delete servicemonitor ${sm} --namespace=${NAMESPACE}
	done
}

echo -n "Removing the petclinic instances..."
remove_petclinic_${CLUSTER_TYPE}
echo "done"
