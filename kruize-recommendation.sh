#!/bin/bash

LOAD_TYPE=$1
APP_NAME=$2

function usage() {
	echo
	echo "Usage: Cluster_type App_name"
	echo "Cluster_type: docker|minikube|openshift" 
	exit -1
}

if [ "$#" -lt 2 ]; then
	usage
fi

if [ "${APP_NAME}" == "acmeair" ]; then
	NAMESPACE="default"
else
	NAMESPACE="openshift-monitoring"
fi

#Get docker recommendation
function docker_recommendation() {
	app_list=($(docker ps --format "{{.Names}}" | grep "${APP_NAME}"))
	for app in "${app_list[@]}"
	do
		curl -H 'Accept: application/json' http://localhost:31313/recommendations?application_name=$app
	done

}

#Get opneshift recommendation
function openshift_recommendation() {
	echo -n "Enter the cluster name   "
	read cluster 
	TOKEN=`oc whoami --show-token`
	app_list=($(oc get deployments --namespace=$NAMESPACE | grep "${APP_NAME}" | cut -d " " -f1))
	for app in "${app_list[@]}"
	do
		curl --silent -k -H "Authorization: Bearer $TOKEN" http://kruize-openshift-monitoring.apps.${cluster}/recommendations?application_name=$app
	done
}

#Get minikube recommendation
function minikube_recommendation() {
	IP=$(minikube ip)
	app_list=($(kubectl get deployments | grep "${APP_NAME}" | cut -d " " -f1))
	for app in "${app_list[@]}"
	do
		curl -H 'Accept: application/json' http://$IP:31313/recommendations?application_name=$app
	done
}

#kruize recommendation
echo	"#############################################################"
echo
echo -n "              kruize recommendation for petclinic.."
echo
echo	"#############################################################"
echo
${LOAD_TYPE}_recommendation
echo 

