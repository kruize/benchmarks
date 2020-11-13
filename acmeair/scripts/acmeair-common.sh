#!/bin/bash

# Set the defaults for the app
export ACMEAIR_PORT="32221"
export NETWORK="acmeair-net"

LOGFILE="${PWD}/setup.log"

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

# Build the acmeair application
function build_acmeair() {
	# Build acmeair monolithic application docker image
	pushd acmeair >>${LOGFILE}
	# Build the application
	docker run --rm -v "$PWD":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle build 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: gradle build of acmeair monolithic application failed."

	# Build the acmeair docker image
	docker-compose -f docker-compose.yml_monolithic build 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: docker-compose of acmeair monolithic application failed."
	popd >>${LOGFILE}
}

# Build the acmeair driver application
function build_acmeair_driver() {
	# Build acmeair driver
	pushd acmeair-driver >>${LOGFILE}
	docker run --rm -v "$PWD":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle build 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: gradle build of acmeair driver failed."
	popd >>${LOGFILE}
}

# Build the jmeter application along with the acmeair driver
function build_jmeter() {
	docker build --pull -t jmeter:3.1 -f Dockerfile.jmeter . 2>>${LOGFILE} >>${LOGFILE}
}

# Pull the jmeter image
function pull_image() {
	JMETER_IMAGE=$1
	docker pull ${JMETER_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to pull the docker image ${JMETER_IMAGE}."
}

# Run the acmeair application and tje mongo db container
function run_acmeair() {
	ACMEAIR_IMAGE=$1
	# Create docker network bridge "acmeair-net"
	docker network create --driver bridge ${NETWORK} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to create docker bridge network ${NETWORK}."

	# Run the mongo DB container on "acmeair-net"
	docker run --rm -d --name=acmeair-db1 --network=${NETWORK} mongo 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start the mongo db container."

	# Run the acmeair app container on "acmeair-net"
	docker run --rm -d --name=acmeair-mono-app1 -p ${ACMEAIR_PORT}:8080 --network=${NETWORK} -e MONGO_HOST='acmeair-db1' ${ACMEAIR_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start acmeair container."
}

# Parse the Throughput Results
function parse_acmeair_results() {
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
