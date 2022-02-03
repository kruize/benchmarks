#!/usr/bin/env bash
#
# Copyright (c) 2020, 2021 Red Hat, IBM Corporation and others.
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
### Script to load test galaxies application on docker,minikube or openshift###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/galaxies-common.sh

function usage() {
	echo
	echo "Usage: -c CLUSTER_TYPE[docker|minikube|openshift] [-i SERVER_INSTANCES] [--iter=MAX_LOOP] [-n NAMESPACE] [-a IP_ADDR] [-t THREAD] [-R REQUEST_RATE] [-d DURATION] [--connection=CONNECTIONS]"
	exit -1
}

while getopts c:i:a:n:t:R:d:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			iter=*)
				MAX_LOOP=${OPTARG#*=}
				;;
			connection=*)
				CONNECTIONS=${OPTARG#*=}
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
	t)
		THREAD="${OPTARG}"
		;;
	R)
		REQUEST_RATE="${OPTARG}"
		;;
	d)
		DURATION="${OPTARG}"
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

if [ -z "${THREAD}" ]; then
	THREAD="10"
fi

if [ -z "${REQUEST_RATE}" ]; then
	REQUEST_RATE="2000"
fi

if [ -z "${DURATION}" ]; then
	DURATION="60"
fi

if [ -z "${CONNECTIONS}" ]; then
	CONNECTIONS="700"
fi

case ${CLUSTER_TYPE} in
docker)
	if [ -z "${IP_ADDR}" ]; then
		get_ip
	fi
	;;
icp|minikube)
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(minikube service list | grep "galaxies" | awk '{print $8}' | tr '\r\n' ' ')
		IFS=' ' read -r -a IP_ADDR <<<  ${IP_ADDR}
	fi
	;;
openshift)
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=($(oc status --namespace=${NAMESPACE} | grep "galaxies" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	fi
	;;
*)
	echo "Load is not determined"
	;;
esac	

LOG_DIR="${PWD}/logs/galaxies-$(date +%Y-%m-%d:%H:%M)"
mkdir -p ${LOG_DIR}

# Check if java is installed and it is of version 11 or newer
check_load_prereq >> setup.log

# Create the required load setup
load_setup >> setup.log

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
		USERS=$(( THREAD*iter ))
		
		case "${CLUSTER_TYPE}" in
			docker)
				cmd="./wrk2.sh --threads=${USERS} --connections=${CONNECTIONS} --duration=${DURATION}s --rate=${REQUEST_RATE} http://${IP_ADDR}:${GALAXIES_PORT}/galaxies"
				;;
			minikube)
				cmd="./wrk2.sh --threads=${USERS} --connections=${CONNECTIONS} --duration=${DURATION}s --rate=${REQUEST_RATE} ${IP_ADDR[inst-1]}/galaxies"
				;;
			openshift)
				cmd="./wrk2.sh --threads=${USERS} --connections=${CONNECTIONS} --duration=${DURATION}s --rate=${REQUEST_RATE} http://${IP_ADDR[inst-1]}/galaxies"
				;;
		esac
		
		# Check if the application is running
		check_app
		# Run the wrk load
		echo "Running wrk load for galaxies instance ${inst} with the following parameters" | tee -a  ${LOG_DIR}/wrk-${inst}-${iter}.log
		echo "CMD=${cmd}" | tee -a  ${LOG_DIR}/wrk-${inst}-${iter}.log
		echo "wrk logs Dir : ${LOG_DIR}"
		sleep 20
		${cmd} >>  ${LOG_DIR}/wrk-${inst}-${iter}.log
		err_exit "can not execute the command"
	done
	((GALAXIES_PORT=GALAXIES_PORT+1))	
	# Parse the results
	parse_galaxies_results ${LOG_DIR} ${MAX_LOOP}
	echo "#########################################################################################"
	echo "				Displaying the results					       "
	echo "#########################################################################################"
	cat ${LOG_DIR}/Throughput.log
done
