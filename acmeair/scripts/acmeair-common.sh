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
### Script containing common functions ###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
pushd "${CURRENT_DIR}" >> setup.log
pushd ".." >> setup.log

# Set the defaults for the app
export ACMEAIR_PORT="32221"
export NETWORK="acmeair-net"
DB_PORT="27017"
LOGFILE="${PWD}/setup.log"
ACMEAIR_REPO=""${CURRENT_DIR}""
ACMEAIR_DEFAULT_IMAGE="dinogun/acmeair-monolithic"
ACMEAIR_CUSTOM_IMAGE="acmeair_mono_service_liberty:latest"
DEFAULT_NAMESPACE="default"
JMETER_CUSTOM_IMAGE="jmeter:3.1"
JMETER_DEFAULT_IMAGE="kruize/jmeter_acmeair:3.1"
MANIFESTS_DIR="manifests/"
JMX_FILE="${PWD}/jmeter-driver/acmeair-jmeter/scripts/AcmeAir.jmx"
LOG="${PWD}/logs"
LOG_FILE="${LOG}/jmeter.log"

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo
		echo "See ${LOGFILE} for more details"
		exit -1
	fi
}

# Check for all the prereqs
function check_prereq() {
	docker version 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: docker not installed \nInstall docker and try again."

	docker-compose version 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: docker-compose not installed \nInstall docker-compose and try again."
}

# Get the IP addr of the machine / vm that we are running on
function get_ip() {
	IP_ADDR=$(ip addr | grep "global" | grep "dynamic" | awk '{ print $2 }' | cut -f 1 -d '/')
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(ip addr | grep "global" | head -1 | awk '{ print $2 }' | cut -f 1 -d '/')
	fi
}

# Build the acmeair application sources and create the docker image
# output:build the application from scratch and create the acmeair docker image 
function build_acmeair() {
	# Build acmeair monolithic application docker image
	pushd acmeair >>${LOGFILE}
	# Build the application
	docker run --rm -v "${PWD}":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle build 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: gradle build of acmeair monolithic application failed."

	# Build the acmeair docker image
	docker-compose -f docker-compose.yml_monolithic build 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: docker-compose of acmeair monolithic application failed."
	popd >>${LOGFILE}
}

# Build the acmeair driver application
function build_acmeair_driver() {
	# Build acmeair driver
	pushd jmeter-driver >>${LOGFILE}
	docker run --rm -v "${PWD}":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle build 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: gradle build of acmeair driver failed."
	popd >>${LOGFILE}
}

# Build the jmeter application along with the acmeair driver
function build_jmeter() {
	docker build --pull -t jmeter_acmeair:3.1 -f Dockerfile.jmeter . 2>>${LOGFILE} >>${LOGFILE}
}

# Pull the jmeter image
# input: jmeter image to be pulled
function pull_image() {
	docker pull ${JMETER_DEFAULT_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to pull the docker image ${JMETER_DEFAULT_IMAGE}."
}

# Run the acmeair application and the mongo db container
# input:acmeair image to be used 
# output:Creates network bridge "acmeair-net" and runs acmeair application container on the same network
function run_acmeair() {
	ACMEAIR_IMAGE=$1
	INST=$2
	# Create docker network bridge "acmeair-net"
	NET_NAME=`docker network ls -f "name=${NETWORK}" --format {{.Name}} | tail -n 1`
	if [[ -z ${NET_NAME} ]];  then
		echo 
		echo "Creating acmeair network: ${NETWORK}..."
		docker network create --driver bridge ${NETWORK} 2>>${LOGFILE} >>${LOGFILE}
	else
		echo "${NETWORK} already exists..." 
	fi


	# Run the mongo DB container on "acmeair-net"
	docker run --rm -d --name=acmeair-db-${INST} --network=${NETWORK} mongo 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start the mongo db container."

	# Run the acmeair app container on "acmeair-net"
	docker run --rm -d --name=acmeair-mono-app-${INST} -p ${ACMEAIR_PORT}:8080 --network=${NETWORK} -e MONGO_HOST=acmeair-db-${INST} ${ACMEAIR_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start acmeair container."
	((ACMEAIR_PORT=ACMEAIR_PORT+1))
	check_app
}

# Check if the application is running
# output: Returns 1 if the application is running else returns 0
function check_app() {
	if [ "${CLUSTER_TYPE}" == "minikube" ]; then
		CMD=$(kubectl get pods | grep "acmeair-sample" | grep "Running" | cut -d " " -f1)
		DB=$(kubectl get pods | grep "acmeair-db" | grep "Running" | cut -d " " -f1)
	elif [ "${CLUSTER_TYPE}" == "openshift" ]; then
		CMD=$(oc get pods --namespace=${NAMESPACE} | grep "acmeair-sample" | grep "Running" | cut -d " " -f1)
		DB=$(oc get pods --namespace=${NAMESPACE} | grep "acmeair-db" | grep "Running" | cut -d " " -f1)
	else
		CMD=$(docker ps | grep "acmeair-mono-app" | cut -d " " -f1)
		DB=$(docker ps | grep "acmeair-db" | cut -d " " -f1)
	fi
	for status in "${CMD[@]}"
	do
		if [ -z "${status}" ]; then
			echo "Acmeair Application did not come up" 
			exit -1;
		fi
	done
	for db_status in "${DB[@]}"
	do
		if [ -z "${db_status}" ]; then
			echo "Mongo db did not come up" 
			exit -1;
		fi
	done
}

# Parse the Throughput Results
# input:result directory , Number of iterations of the jmeter load
# output:Throughput log file (throughput, Number of pages it has retreived, average response time and errors if any)
function parse_acmeair_results() {
	RESULTS_DIR=$1
	TOTAL_LOGS=$2
	echo "RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS" > ${RESULTS_DIR}/Throughput.log
	for (( log=1 ; log<=${TOTAL_LOGS} ;log++))
	do
		RESULT_LOG=${RESULTS_DIR}/jmeter-${inst}-${log}.log
		summary=`cat ${RESULT_LOG} | sed 's%<summary>%%g' | grep "summary = " | tail -n 1`
		throughput=`echo ${summary} | awk '{print $7}' | sed 's%/s%%g'`
		responsetime=`echo ${summary} | awk '{print $9}' | sed 's%/s%%g'`
		weberrors=`echo ${summary} | awk '{print $15}' | sed 's%/s%%g'`
		pages=`echo ${summary} | awk '{print $3}' | sed 's%/s%%g'`
		echo "${log},${throughput},${pages},${responsetime},${weberrors}" >> ${RESULTS_DIR}/Throughput.log
	done
}
