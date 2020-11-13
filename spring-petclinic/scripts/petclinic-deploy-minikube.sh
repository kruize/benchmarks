#!/bin/bash

ROOT_DIR=.
pushd ${ROOT_DIR}
# Run the benchmark as
# SCRIPT  MANIFESTS_DIR 
# Ex of ARGS :   rt-cloud-benchmarks/spring-petclinic/manifests 

LOGFILE="${ROOT_DIR}/setup.log"
MANIFESTS_DIR=$1

if [[  -z $MANIFESTS_DIR ]]; then
	echo "Do set the variable -   MANIFESTS_DIR "
	exit 1
fi

function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo "See ${LOGFILE} for more details"
		exit -1
	fi
}

function createInstances() {
	# Deploy service monitor to get Java Heap recommendations from petclinic$
	kubectl apply -f $MANIFESTS_DIR/service-monitor.yaml

	#Create the deployments and services
	kubectl apply -f $MANIFESTS_DIR/petclinic.yaml 
	err_exit "Error: Issue in deploying."

	#Wait till petclinic starts
	sleep 40
}

function stopAllInstances() {
	# Delete the deployments first to avoid creating replica pods
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

# Stop all petclinic related instances if there are any
stopAllInstances
# Deploying instances
createInstances $SERVER_INSTANCES
