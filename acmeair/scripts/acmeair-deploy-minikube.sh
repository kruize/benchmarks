#!/bin/bash

ROOT_DIR=.
pushd ${ROOT_DIR}
# Run the benchmark as
# SCRIPT  MANIFESTS_DIR 
# Ex of ARGS :   rt-cloud-benchmarks/acmeair/manifests 

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
	#Create the deployments and services
	kubectl apply -f $MANIFESTS_DIR/mongo-db.yaml
	kubectl apply -f $MANIFESTS_DIR/acmeair.yaml  
	err_exit "Error: Issue in deploying."

	#Wait till petclinic starts
	sleep 40
}

function stopAllInstances() {
	# Delete the deployments first to avoid creating replica pods
	acmeair_deployments=($(kubectl get deployments  | grep "acmeair" | cut -d " " -f1))
	
	for de in "${acmeair_deployments[@]}"	
	do
		kubectl delete deployment $de 
	done

	#Delete the services and routes if any
	acmeair_services=($(kubectl get services  | grep "acmeair" | cut -d " " -f1))
	for se in "${acmeair_services[@]}"
	do
		kubectl delete service $se 
	done
	
}

# Stop all petclinic related instances if there are any
stopAllInstances
# Deploying instances
createInstances $SERVER_INSTANCES
