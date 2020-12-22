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
### Script to load test acmeair app ###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/acmeair-common.sh

function usage() {
	echo
	echo "Usage: -c CLUSTER_TYPE[docker|minikube|openshift] [-i SERVER_INSTANCES] [--iter=MAX_LOOP] [-a IP_ADDR] [-n NAMESPACE]"
	exit -1
}

while getopts c:i:a:n:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			iter=*)
				MAX_LOOP=${OPTARG#*=}
				;;
		esac
		;;
	c)
		CLUSTER_TYPE=${OPTARG}
		;;
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	a)
		IP_ADDR="${OPTARG}"		
		;;
	n)
		NAMESPACE="${OPTARG}"		
		;;
	esac
done

if [ -z "${CLUSTER_TYPE}" ]; then
	usage
fi

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${MAX_LOOP}" ]; then
	MAX_LOOP=5
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="${DEFAULT_NAMESPACE}"
fi

LOG_DIR="${LOG}/acmeair-$(date +%Y%m%d%H%M)"
mkdir -p ${LOG_DIR}

case $CLUSTER_TYPE in
docker)
	if [ -z "${IP_ADDR}" ]; then
		get_ip
	fi
	if [[ "$(docker images -q ${JMETER_CUSTOM_IMAGE} 2> /dev/null)" == "" ]]; then
		JMETER_FOR_LOAD="${JMETER_DEFAULT_IMAGE}"
	else
		JMETER_FOR_LOAD="${JMETER_CUSTOM_IMAGE}"
	fi
	err_exit "Error: Unable to load the jmeter image"
	;;
icp|minikube)
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(minikube ip)
	fi
	if [[ "$(docker images -q ${JMETER_CUSTOM_IMAGE} 2> /dev/null)" == "" ]]; then
		JMETER_FOR_LOAD="${JMETER_DEFAULT_IMAGE}"
	else
		JMETER_FOR_LOAD="${JMETER_CUSTOM_IMAGE}"
	fi
	err_exit "Error: Unable to load the jmeter image"
	;;
openshift)
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=($(oc status --namespace=${NAMESPACE} | grep "acmeair" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	fi
	JMETER_FOR_LOAD="${JMETER_DEFAULT_IMAGE}"
	err_exit "Error: Unable to load the jmeter image"
	;;
*)
	echo "Load is not determined"
	;;
esac		

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
	
		sleep 120 
	
		# Check if the application is running
		# output: Returns 1 if the pod is running else returns 0.
		check_app
		if [ "$STATUS" == 0 ]; then
			echo "Application did not come up"
			exit 0;
		fi
		
		if [ ${CLUSTER_TYPE} == "openshift" ]; then
			# Load dummy users into the DB
			wget -O- http://${IP_ADDR[inst-1]}/rest/info/loader/load?numCustomers=${JMETER_LOAD_USERS}  2> ${LOGFILE}
			err_exit "Error: Could not load the dummy users into the DB"
			cmd="docker run --rm -e Jdrivers=${JMETER_LOAD_USERS} -e Jduration=${JMETER_LOAD_DURATION} -e Jhost=${IP_ADDR[inst-1]} ${JMETER_FOR_LOAD} "
		else
			# Load dummy users into the DB
			wget -O- http://${IP_ADDR}:${ACMEAIR_PORT}/rest/info/loader/load?numCustomers=${JMETER_LOAD_USERS} 2> ${LOGFILE}
			err_exit "Error: Could not load the dummy users into the DB"
			cmd="docker run --rm -e Jdrivers=${JMETER_LOAD_USERS} -e Jduration=${JMETER_LOAD_DURATION} -e Jhost=${IP_ADDR} -e Jport=${ACMEAIR_PORT} ${JMETER_FOR_LOAD}"
		fi 
	
		echo " "
	
		# Reset the max user id value to default
		git checkout ${JMX_FILE}

		# Calculate maximum user ids based on the USERS values passed
		MAX_USER_ID=$(( JMETER_LOAD_USERS-1 ))

		# Update the jmx value with the max user id
		sed -i 's/"maximumValue">99</"maximumValue">'${MAX_USER_ID}'</' ${JMX_FILE}
	
		# Run the jmeter load
		echo "Running jmeter load for petclinic instance $inst with the following parameters"
		echo "${cmd}"
		echo "jmter logs Dir : ${LOG_DIR}"
		${cmd} > ${LOG_DIR}/jmeter-${inst}-${iter}.log
		err_exit "can not execute the command"
	done
	((ACMEAIR_PORT=ACMEAIR_PORT+1))
	
	# Reset the max user value to previous value
	git checkout ${JMX_FILE} > ${LOGFILE}

	# Reset the jmx maximumValue 
	sed -i 's/"maximumValue">'${MAX_USER_ID}'</"maximumValue">'99'</' ${JMX_FILE}

	# Parse the results
	# input:result directory , Number of iterations of the jmeter load
	# output:Throughput log file
	parse_acmeair_results ${LOG_DIR} ${MAX_LOOP}
	echo "#########################################################################################"
	echo "				Displaying the results					       "
	echo "#########################################################################################"
	cat ${LOG_DIR}/Throughput.log
done
