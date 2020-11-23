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
### Script to load test petclinic application on docker,minikube or openshift###
#
# Script to load test petclinic app
# 

NAMESPACE="openshift-monitoring"

source ./scripts/petclinic-common.sh

function usage() {
	echo
	echo "Usage: [load_type] [Total Number of instances] [Number of iterations of the jmeter load] [ip_adddr / namespace]"
	echo "load_type : docker minikube openshift "
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

LOAD_TYPE=$1
SERVER_INSTANCES=$2
MAX_LOOP=$3
IP_ADDR=$4

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${MAX_LOOP}" ]; then
	MAX_LOOP=5
else
	MAX_LOOP=$3
fi

case $LOAD_TYPE in
docker)
	if [ -z "${IP_ADDR}" ]; then
		get_ip
	fi
	if [[ "$(docker images -q jmeter_petclinic:3.1 2> /dev/null)" != "" ]]; then
		JMETER_FOR_LOAD="jmeter_petclinic:3.1" 
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
		IP_ADDR=($(oc status --namespace=$NAMESPACE | grep "petclinic" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	fi
	JMETER_FOR_LOAD="kruize/jmeter_petclinic:noport"
	;;
*)
	echo "Load is not determined"
	;;
esac	

LOG_DIR="${PWD}/logs/petclinic-$(date +%Y%m%d%H%M)"
mkdir -p ${LOG_DIR}

for(( inst=1; inst<=${SERVER_INSTANCES}; inst++ ))
do
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
			cmd="docker run --rm -e JHOST=${IP_ADDR} -e JDURATION=${JMETER_LOAD_DURATION} -e JUSERS=${JMETER_LOAD_USERS} -e JPORT=${PETCLINIC_PORT} ${JMETER_FOR_LOAD}"
		fi
		
		# Check if the application is running
		check_app
		if [ "$STATUS" == 0 ]; then
			echo "Application pod did not come up"
			exit 0;
		fi
	
		# Run the jmeter load
		echo "Running jmeter load for petclinic instance $inst with the following parameters"
		echo "${cmd}"
		echo "jmter logs Dir : ${LOG_DIR}"
		${cmd} > ${LOG_DIR}/jmeter-${inst}-${iter}.log
		err_exit "can not execute the command"
	done	
	((PETCLINIC_PORT=PETCLINIC_PORT+1))

	# Parse the results
	parse_petclinic_results ${LOG_DIR} ${MAX_LOOP}
	echo "#########################################################################################"
	echo "				Displaying the results					       "
	echo "#########################################################################################"
	cat ${LOG_DIR}/Throughput.log
done
