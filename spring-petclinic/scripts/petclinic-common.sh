#!/bin/bash

# Set the defaults for the app
export PETCLINIC_PORT="32334"
export NETWORK="kruize-network"
CPU="2.5"
MEMORY="1024M"
ROOT_DIR=${PWD}
LOGFILE="${ROOT_DIR}/setup.log"
PORT="8080"

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
function build_petclinic() {
	IMAGE=$1
	# Build the application from git clone. Requires git , JAVA compiler on your machine to work.
	git clone https://github.com/spring-projects/spring-petclinic.git 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to clone the git repo"
	pushd spring-petclinic >>${LOGFILE}
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

# Pull the jmeter image
function pull_image() {
	JMETER_IMAGE=$1
	docker pull ${JMETER_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to pull the docker image ${JMETER_IMAGE}."
}

# Run the petclinic application 
function run_petclinic() {
	PETCLINIC_IMAGE=$1   
	ARGS=$2   
	if [ "$1" == "kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0" ]; then
		PORT=8081
	fi   
	# Create docker network bridge "petclinic-net"
	docker network create --driver bridge ${NETWORK} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to create docker bridge network ${NETWORK}."

	# Run the petclinic app container on "petclinic-net"
	docker run -d --name=petclinic-app --cpus=${CPU} --memory=${MEMORY} -p ${PETCLINIC_PORT}:${PORT} --network=${NETWORK} -e JVM_ARGS=${ARGS} ${PETCLINIC_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start petclinic container."
}
 
# Parse the Throughput Results
function parse_petclinic_results() {
	RESULTS_DIR=$1
	TOTAL_LOGS=$2
	echo "RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS" > ${RESULTS_DIR}/Throughput.log
	for (( log=1 ; log<=${TOTAL_LOGS} ;log++))
	do
		RESULT_LOG=${RESULTS_DIR}/jmeter-${log}.log
		summary=`cat $RESULT_LOG | sed 's%<summary>%%g' | grep "summary = " | tail -n 1`
		throughput=`echo $summary | awk '{print $7}' | sed 's%/s%%g'`
		responsetime=`echo $summary | awk '{print $9}' | sed 's%/s%%g'`
		weberrors=`echo $summary | awk '{print $15}' | sed 's%/s%%g'`
		pages=`echo $summary | awk '{print $3}' | sed 's%/s%%g'`
		echo "$log,$throughput,$pages,$responsetime,$weberrors" >> ${RESULTS_DIR}/Throughput.log
	done
}
