#!/bin/bash
#
# Script to load test petclinic app
# 

source ./scripts/petclinic-common.sh

function usage() {
	echo
	echo "Usage: docker [Number of iterations of the jmeter load] [ip_adddr / namespace]"
	echo "load_type : docker icp openshift "
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

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
	JMETER_FOR_LOAD="jmeter_petclinic:3.1"
	;;
icp|minikube)
	if [ -z "${IP_ADDR}" ]; then
		echo " IP_ADDR not set.Cannot run ICP load"
		exit -1
	fi

	JMETER_FOR_LOAD="jmeter_petclinic:3.1"
	;;
openshift)
	if [ -z "${IP_ADDR}" ]; then
		NAMESPACE="openshift-monitoring"
		IP_ADDR=($(oc status --namespace=$NAMESPACE | grep "petclinic" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	fi
	JMETER_FOR_LOAD="kusumach/petclinic_jmeter_noport:0423"
	PORT=8888
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
	# Run the jmeter load
	echo "Running jmeter load with the following parameters"
	echo "JHOST=${IP_ADDR} JDURATION=${JMETER_LOAD_DURATION} JUSERS=${JMETER_LOAD_USERS} JPORT=${PORT} "
	echo "jmter logs Dir : ${LOG_DIR}"
	docker run --rm -e JHOST=${IP_ADDR} -e JDURATION=${JMETER_LOAD_DURATION} -e JUSERS=${JMETER_LOAD_USERS} -e JPORT=${PORT} $JMETER_FOR_LOAD > ${LOG_DIR}/jmeter-${iter}.log
done

# Parse the results
parse_petclinic_results ${LOG_DIR} ${MAX_LOOP}
echo "#########################################################################################"
echo "				Displaying the results					       "
echo "#########################################################################################"
cat ${LOG_DIR}/Throughput.log

