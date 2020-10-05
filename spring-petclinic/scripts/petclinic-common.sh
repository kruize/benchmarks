#!/bin/bash

# Set the defaults for the app
export PETCLINIC_PORT="32334"
export NETWORK="petclinic-net"
export JMETER_IMAGE

LOGFILE="${ROOT_DIR}/setup.log"

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

#	docker-compose version 2>>${LOGFILE} >>${LOGFILE}
#	err_exit "Error: docker-compose not installed \nInstall docker-compose and try again."
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
	# Build petclinic application 
	pushd spring-petclinic >>${LOGFILE}

	# Build the application from git clone. Requires git , JAVA compiler on your machine to work.
	# Commenting this for now and using the built-in jar
	git clone https://github.com/spring-projects/spring-petclinic.git 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to clone the git repo"
	pushd spring-petclinic >>${LOGFILE}
	./mvnw package 2>>${LOGFILE} >>${LOGFILE}
        
	err_exit "Error: Unable to build the benchmark"
	popd >>${LOGFILE}

	#pushd Spring-petclinic >>${LOGFILE}
	# Build the petclinic docker image
	docker build -t spring-petclinic . 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Building of docker image of petclinic."
	popd >>${LOGFILE}
}


# Build the jmeter application along with the petclinic
function build_jmeter() {
	pushd spring-petclinic >>${LOGFILE}
	#./mvnw package 2>>${LOGFILE} >>${LOGFILE}
	docker build --pull -t jmeter_petclinic:3.1 -f Dockerfile_jmeter . 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Building of jmeter image."
	popd >>${LOGFILE}
       
}


# Pull the jmeter image
function pull_image() {
	JMETER_IMAGE=$1
	
	docker pull ${JMETER_IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to pull the docker image ${JMETER_IMAGE}."
}


# Run the petclinic application 
function run_petclinic() {
	IMAGE=$1      
	               
	# Create docker network bridge "petclinic-net"
	docker network create --driver bridge ${NETWORK} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to create docker bridge network ${NETWORK}."

	# Run the petclinic app container on "petclinic-net"
	docker run --rm -d --name=petclinic-app --cpus="2.0" --memory="1024M" -p ${PETCLINIC_PORT}:8080 --network=${NETWORK} ${IMAGE} 2>>${LOGFILE} >>${LOGFILE}
	err_exit "Error: Unable to start petclinic container."
	#export USEDIMAGE="$IMAGE"
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


