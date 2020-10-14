#!/bin/bash

ROOT_DIR=.
pushd ${ROOT_DIR}
# Run the benchmark as
# SCRIPT BENCHMARK_SERVER NAMESPACE MANIFESTS_DIR RESULTS_DIR_PATH
# Ex of ARGS :  wobbled.os.fyre.ibm.com openshift-monitoring rt-cloud-benchmarks/spring-petclinic/manifests /petclinic/results
BENCHMARK_SERVER=$1
NAMESPACE=$2
MANIFESTS_DIR=$3
RESULTS_DIR_PATH=$4
SERVER_INSTANCES=$5

if [[ -z $BENCHMARK_SERVER || -z $NAMESPACE || -z $RESULTS_DIR_PATH || -z $MANIFESTS_DIR ]]; then
  echo "Do set all the variables - BENCHMARK_SERVER , NAMESPACE , MANIFESTS_DIR and RESULTS_DIR_PATH"
  exit 1
fi

if [ -z "${SERVER_INSTANCES}" ]; then
    SERVER_INSTANCES=1
else
    SERVER_INSTANCES=$5
fi

RESULTS_DIR_ROOT=$RESULTS_DIR_PATH/petclinic-$(date +%Y%m%d%H%M)
mkdir -p $RESULTS_DIR_ROOT

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
	#Using inmem DB so no DB specific pods	
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
                sed 's/petclinic/petclinic-'$inst'/g' $MANIFESTS_DIR/service-monitor.yaml > $MANIFESTS_DIR/service-monitor-$inst.yaml
                sed -i 's/petclinic-app/petclinic-app-'$inst'/g' $MANIFESTS_DIR/service-monitor-$inst.yaml
                sed -i 's/petclinic-port/petclinic-port-'$inst'/g' $MANIFESTS_DIR/service-monitor-$inst.yaml
	done
	for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
	do
                sed 's/petclinic-sample/petclinic-sample-'$inst'/g' $MANIFESTS_DIR/petclinic.yaml > $MANIFESTS_DIR/petclinic-$inst.yaml
                sed -i 's/petclinic-service/petclinic-service-'$inst'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
                sed -i 's/petclinic-app/petclinic-app-'$inst'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
                sed -i 's/petclinic-port/petclinic-port-'$inst'/g' $MANIFESTS_DIR/petclinic-$inst.yaml
                oc create -f $MANIFESTS_DIR/petclinic-$inst.yaml -n $NAMESPACE
                err_exit "Error: Issue in deploying."
	done

	#Wait till petclinic starts
	sleep 40
	#Expose the services
	svc_list=($(oc get svc --namespace=$NAMESPACE | grep "service" | grep "petclinic" | cut -d " " -f1))
	for sv in "${svc_list[@]}"
	do
		oc expose svc/$sv --namespace=$NAMESPACE
		err_exit " Error: Issue in exposing service"
	done
}

function stopAllInstances() {
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
}

# Stop all petclinic related instances if there are any
stopAllInstances
# Deploying instances
createInstances $SERVER_INSTANCES
