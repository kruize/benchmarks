#!/bin/bash
#
# Script to load test petclinic app
# 

source ./scripts/petclinic-common.sh

function usage() {
	echo
	echo "Usage: docker [Number of iterations of the jmeter load] [ip_adddr / namespace]"
	echo "load_type : docker minikube openshift "
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo
		echo "See ${LOGFILE} for more details"
		exit -1
	fi
}

LOAD_TYPE=$1
MAX_LOOP=$2
IP_ADDR=$3
PORT=$4

if [ -z "${MAX_LOOP}" ]; then
	MAX_LOOP=5
else
	MAX_LOOP=$2
fi

if [ -z "${PORT}" ]; then
	PORT=${PETCLINIC_PORT}
fi

case $LOAD_TYPE in
docker)
	if [ -z "${IP_ADDR}" ]; then
		get_ip
	fi
	if [[ "$(docker images -q jmeter_petclinic:3.1 2> /dev/null)" != "" ]]; then
		JMETER_FOR_LOAD="jmeter_petclinic:3.1"
	elif [[ "$(docker images -q */jmeter*:* 2> /dev/null)" != "" ]]; then
		JMETER_FOR_LOAD=$(docker images -q */jmeter*:*) 
	else
		JMETER_FOR_LOAD=docker.io/kruize/jmeter_petclinic:3.1
	fi
	err_exit "Error: Unable to load the jmeter image"
	
	;;
icp|minikube)
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(minikube ip)
	fi
	if [[ "$(docker images -q jmeter_petclinic:3.1 2> /dev/null)" == "" ]]; then
		JMETER_FOR_LOAD=docker.io/kruize/jmeter_petclinic:3.1
	else
		JMETER_FOR_LOAD="jmeter_petclinic:3.1"
	fi
	;;
openshift)
	if [ -z "${IP_ADDR}" ]; then
		NAMESPACE="openshift-monitoring"
		IP_ADDR=($(oc status --namespace=$NAMESPACE | grep "petclinic" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	fi
	JMETER_FOR_LOAD=" kruize/jmeter_petclinic:noport"
	;;
*)
	echo "Load is not determined"
	;;
esac	

LOG_DIR="${PWD}/logs/petclinic-$(date +%Y%m%d%H%M)"
mkdir -p ${LOG_DIR}

for iter in `seq 1 ${MAX_LOOP}`
do
	echo
	echo "#########################################################################################"
	echo "                             Starting Iteration ${iter}                                  "
	echo "#########################################################################################"
	echo
	
	# Change these appropriately to vary load
	JMETER_LOAD_USERS=$(( 150*iter ))
	JMETER_LOAD_DURATION=20
	
	if [ "${LOAD_TYPE}" == "openshift" ]; then
		cmd="docker run  --rm -e JHOST=${IP_ADDR} -e JDURATION=${JMETER_LOAD_DURATION} -e JUSERS=${JMETER_LOAD_USERS} ${JMETER_FOR_LOAD}" 
	else
		cmd="docker run --rm -e JHOST=${IP_ADDR} -e JDURATION=${JMETER_LOAD_DURATION} -e JUSERS=${JMETER_LOAD_USERS} -e JPORT=${PORT} ${JMETER_FOR_LOAD}"
	fi
	# Run the jmeter load
	echo "Running jmeter load with the following parameters"
	echo "${cmd}"
	echo "jmter logs Dir : ${LOG_DIR}"
	${cmd} > ${LOG_DIR}/jmeter-${iter}.log
	err_exit "can not execute the command"
	echo "${JMETER_FOR_LOAD}"
done

# Parse the results
parse_petclinic_results ${LOG_DIR} ${MAX_LOOP}
echo "#########################################################################################"
echo "				Displaying the results					       "
echo "#########################################################################################"
cat ${LOG_DIR}/Throughput.log
