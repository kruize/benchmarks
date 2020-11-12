#!/bin/bash

ROOT_DIR=.
pushd ${ROOT_DIR}
# Run the benchmark as
# SCRIPT BENCHMARK_SERVER NAMESPACE MANIFESTS_DIR RESULTS_DIR_PATH
# Ex of ARGS :  wobbled.os.fyre.ibm.com openshift-monitoring rt-cloud-benchmarks/acmeair/manifests /acmeair/results
BENCHMARK_SERVER=$1
NAMESPACE=$2
MANIFESTS_DIR=$3
SERVER_INSTANCES=$4

if [[ -z $BENCHMARK_SERVER || -z $NAMESPACE || -z $MANIFESTS_DIR ]]; then
	echo "Do set all the variables - BENCHMARK_SERVER , NAMESPACE and MANIFESTS_DIR" 
	exit 1
fi

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
else
	SERVER_INSTANCES=$4
fi

function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo "See ${LOGFILE} for more details"
		exit -1
	fi
}

function createInstances() {
	# Create multiple yamls based on instances and Update the template yamls with names and create multiple files
	# #Create the deployments and services
	db_port=27017
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/acmeair-db/acmeair-db-'$inst'/g' $MANIFESTS_DIR/mongo-db.yaml > $MANIFESTS_DIR/mongo-db-$inst.yaml
		sed -i 's/27017/'$db_port'/g' $MANIFESTS_DIR/mongo-db-$inst.yaml
		oc create -f $MANIFESTS_DIR/mongo-db-$inst.yaml -n $NAMESPACE
		err_exit "Error: Issue in deploying."
		((db_port=db_port+1))
	done

	acmeair_port=32221
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
		sed 's/acmeair-sample/acmeair-sample-'$inst'/g' $MANIFESTS_DIR/acmeair.yaml > $MANIFESTS_DIR/acmeair-$inst.yaml
		sed -i 's/acmeair-service/acmeair-service-'$inst'/g' $MANIFESTS_DIR/acmeair-$inst.yaml
		sed -i 's/acmeair-app/acmeair-app-'$inst'/g' $MANIFESTS_DIR/acmeair-$inst.yaml
		sed -i 's/32221/'$acmeair_port'/g' $MANIFESTS_DIR/acmeair-$inst.yaml
		oc create -f $MANIFESTS_DIR/acmeair-$inst.yaml -n $NAMESPACE
		err_exit "Error: Issue in deploying."
		((acmeair_port=acmeair_port+1))
	done
	
	# Server instances on different worker node
	# Hard coded the node name for now
	# TODO for automation
	#Wait till acmeair starts
	sleep 40
	#Expose the services
	svc_list=($(oc get svc --namespace=$NAMESPACE | grep "service" | grep "acmeair" | cut -d " " -f1))
	for sv in "${svc_list[@]}"
	do
		oc expose svc/$sv --namespace=$NAMESPACE
		err_exit " Error: Issue in exposing service"
	done
}

function stopAllInstances() {
	# Delete the deployments first to avoid creating replica pods
	acmeair_deployments=($(oc get deployments --namespace=$NAMESPACE | grep "acmeair" | cut -d " " -f1))
	
	for de in "${acmeair_deployments[@]}"	
	do
		oc delete deployment $de --namespace=$NAMESPACE
	done

	#Delete the services and routes if any
	acmeair_services=($(oc get services --namespace=$NAMESPACE | grep "acmeair" | cut -d " " -f1))
	for se in "${acmeair_services[@]}"
	do
		oc delete service $se --namespace=$NAMESPACE
	done
	acmeair_routes=($(oc get route --namespace=$NAMESPACE | grep "acmeair" | cut -d " " -f1))
	for ro in "${acmeair_routes[@]}"
	do
		oc delete route $ro --namespace=$NAMESPACE
	done
}

# Stop all petclinic related instances if there are any
stopAllInstances
# Deploying instances
createInstances $SERVER_INSTANCES
