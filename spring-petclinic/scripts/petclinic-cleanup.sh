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

ROOT_DIR=".."
source ./scripts/petclinic-common.sh
pushd ${ROOT_DIR}

function usage() {
	echo
	echo "Usage: cluster_type [docker|minikube|openshift]"
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

CLUSTER_TYPE=$1

function remove_petclinic_docker() {
	petclinic_containers=$(docker ps -q)
	for con in "${petclinic_containers[@]}"
	do
		if [ $con ]; then
			# stop the petclinic container
			docker stop $con
			# remove the petclinic container
			docker rm $con
		fi
	done

	# remove the petclinic network
	docker network rm ${NETWORK}

	# remove the petclinic image if present
	if [[ "$(docker images -q spring-petclinic:latest 2> /dev/null)" != "" ]]; then
		docker rmi spring-petclinic:latest
	fi
	
	# remove the jmeter image if present
	if [[ "$(docker images -q jmeter_petclinic:3.1 2> /dev/null)" != "" ]]; then
		docker rmi jmeter_petclinic:3.1
	fi
}

function remove_petclinic_minikube() {
	petclinic_deployments=($(kubectl get deployments  | grep "petclinic" | cut -d " " -f1))
	
	for de in "${petclinic_deployments[@]}"	
	do
		kubectl delete deployment $de 
	done

	#Delete the services and routes if any
	petclinic_services=($(kubectl get services  | grep "petclinic" | cut -d " " -f1))
	for se in "${petclinic_services[@]}"
	do
		kubectl delete service $se 
	done	
}

function remove_petclinic_openshift() {
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

echo -n "Removing the petclinic instances..."
remove_petclinic_${CLUSTER_TYPE}
echo "done"
