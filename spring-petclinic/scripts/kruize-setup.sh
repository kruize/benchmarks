#!/bin/bash

function usage() {
	echo
	echo "Usage: Cluster_type"
	echo "Cluster_type: docker|minikube|openshift" 
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

ROOT_DIR="${PWD}"
LOGFILE="${ROOT_DIR}/kruize.log"
export LOAD_TYPE=$1

function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo
		echo "See ${LOGFILE} for more details"
		exit -1
	fi
}

function kruize_setup() {
	pushd ${ROOT_DIR} 2>>${LOGFILE}
	git clone https://github.com/kruize/kruize.git 2>>${LOGFILE}  
	err_exit "Error: Unable to clone the git repo"
}

function kruize_deploy() {
	pushd kruize 2>>${LOGFILE}
	./deploy.sh -c ${LOAD_TYPE}
}

# create kruize setup
echo -n "Creating kruize setup..."
kruize_setup
echo "done"

# deploy kruize
echo -n "Deploying kruize on ${LOAD_TYPE} ..."
kruize_deploy
echo "done"

