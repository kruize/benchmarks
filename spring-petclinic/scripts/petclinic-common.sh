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
export PETCLINIC_PORT="32334"
export NETWORK="kruize-network"
LOGFILE="${CURRENT_DIR}/setup.log"
PETCLINIC_REPO="${CURRENT_DIR}"
PETCLINIC_DEFAULT_IMAGE="kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0"
PETCLINIC_CUSTOM_IMAGE="spring-petclinic:latest"
DEFAULT_NAMESPACE="openshift-monitoring"
JMETER_CUSTOM_IMAGE="jmeter_petclinic:3.1"
JMETER_DEFAULT_IMAGE="kruize/jmeter_petclinic:3.1"
MANIFESTS_DIR="manifests/"

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
}

# Get the IP addr of the machine / vm that we are running on
function get_ip() {
	IP_ADDR=$(ip addr | grep "global" | grep "dynamic" | awk '{ print $2 }' | cut -f 1 -d '/')
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(ip addr | grep "global" | head -1 | awk '{ print $2 }' | cut -f 1 -d '/')
	fi
}

# Build the petclinic application
# input:base_image 
# output:build the application from scratch and create the petclinic docker image with the specified base_image(input)
function build_petclinic() {
	IMAGE=$1
	# Build the application from git clone. Requires git , JAVA compiler on your machine to work.
	git clone https://github.com/spring-projects/spring-petclinic.git 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to clone the git repo"
	pushd spring-petclinic >>${LOGFILE}
	# Change the server port in application.properties
	sed -i '1 s/^/server.port=8081\n/' src/main/resources/application.properties
	sed -i '19imanagement.endpoints.web.base-path=/manage\n' src/main/resources/application.properties
	./mvnw package 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to build the benchmark"
	popd >>${LOGFILE}
	
	# Build the petclinic docker image
	docker build -t spring-petclinic --build-arg REPOSITORY=${IMAGE} . 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Building of docker image of petclinic."
}

# Build the jmeter application along with the petclinic 
function build_jmeter() {
	docker build --pull -t jmeter_petclinic:3.1 -f Dockerfile_jmeter . 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Building of jmeter image."
}

# Set the port number according to the petclinic image passed
# input: petclinic image
# output: Set port number to 8081 if the input petclinic image is same as default image or the custom image built during petclinic-build, else set the port number to 8080
function set_port() {
	PETCLINIC_IMAGE=$1
	if [[ "${PETCLINIC_IMAGE}" == "${PETCLINIC_DEFAULT_IMAGE}"  || "${PETCLINIC_IMAGE}" == "${PETCLINIC_CUSTOM_IMAGE}" ]]; then
		PORT=8081
	else
		PORT=8080
fi
}
# Pull the jmeter image
# input: jmeter image to be pulled
function pull_image() {
	docker pull ${JMETER_DEFAULT_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to pull the docker image ${JMETER_DEFAULT_IMAGE}."
}

# Run the petclinic application 
# input:petclinic image to be used and JVM arguments if any
# output:Create network bridge "kruize-network" and run petclinic application container on the same network
function run_petclinic() {
	PETCLINIC_IMAGE=$1 
	INST=$2
	JVM_ARGS=$3     
	
	set_port ${PETCLINIC_IMAGE}
	# Create docker network bridge "kruize-network"
	NET_NAME=`docker network ls -f "name=${NETWORK}" --format {{.Name}} | tail -n 1`
	echo
	if [[ -z ${NET_NAME} ]];  then
		echo "Creating Kruize network: ${NETWORK}..."
		docker network create --driver bridge ${NETWORK} 2>>${LOGFILE} >>${LOGFILE}
	else
		echo "${NETWORK} already exists..." 
	fi

	# Run the petclinic app container on "kruize-network"
	cmd="docker run -d --name=petclinic-app-${INST} -p ${PETCLINIC_PORT}:${PORT} --network=${NETWORK} -e JVM_ARGS=${JVM_ARGS} ${PETCLINIC_IMAGE} "
	${cmd}s 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start petclinic container."
	((PETCLINIC_PORT=PETCLINIC_PORT+1))
	# Check if the application is running
	check_app
}

# Check if the application is running
# output: Returns 1 if the application is running else returns 0
function check_app() {
	if [ "${CLUSTER_TYPE}" == "minikube" ]; then
		CMD=$(kubectl get pods | grep "petclinic" | grep "Running" | cut -d " " -f1)
	elif [ "${CLUSTER_TYPE}" == "openshift" ]; then
		CMD=$(oc get pods --namespace=${NAMESPACE} | grep "petclinic" | grep "Running" | cut -d " " -f1)
	else
		CMD=$(docker ps | grep "petclinic-app" | cut -d " " -f1)
	fi
	for status in "${CMD[@]}"
	do
		if [ -z "${status}" ]; then
			echo "Application pod did not come up" 
			exit -1;
		fi
	done
}

# Parse the Throughput Results
# input:result directory , Number of iterations of the jmeter load
# output:Throughput log file (throughput, Number of pages it has retreived, average response time and errors if any)
function parse_petclinic_results() {
	RESULTS_DIR=$1
	TOTAL_LOGS=$2
	echo "RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS" > ${RESULTS_DIR}/Throughput.log
	for (( iteration=1 ; iteration<=${TOTAL_LOGS} ;iteration++))
	do
		RESULT_LOG=${RESULTS_DIR}/jmeter-${inst}-${iteration}.log
		summary=`cat ${RESULT_LOG} | sed 's%<summary>%%g' | grep "summary = " | tail -n 1`
		throughput=`echo ${summary} | awk '{print $7}' | sed 's%/s%%g'`
		responsetime=`echo ${summary} | awk '{print $9}' | sed 's%/s%%g'`
		weberrors=`echo ${summary} | awk '{print $15}' | sed 's%/s%%g'`
		pages=`echo ${summary} | awk '{print $3}' | sed 's%/s%%g'`
		echo "${iteration},${throughput},${pages},${responsetime},${weberrors}" >> ${RESULTS_DIR}/Throughput.log
	done
}
