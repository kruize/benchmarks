#!/bin/bash
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
### Script containing common functions ###

CURRENT_DIR="$(dirname "$(realpath "$0")")"
pushd "${CURRENT_DIR}" > /dev/null
pushd ".." > /dev/null

# Set the defaults for the app
export TFB_PORT="32000"
export NETWORK="kruize-network"
LOGFILE="${PWD}/setup.log"
TFB_REPO="${CURRENT_DIR}"
TFB_DEFAULT_IMAGE="kruize/tfb-qrh:1.13.2.F_mm.v1"
TFB_CUSTOM_IMAGE="tfb-qrh:latest"
DEFAULT_NAMESPACE="default"
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

# Check if java is installed and it is of version 11 or newer
function check_load_prereq() {
	echo
	echo -n "Info: Checking prerequisites..." >> ${LOGFILE} 
	# check if java exists
	if [ ! `which java` ]; then
		echo " "
		echo "Error: java is not installed."
		exit 1
	else
		JAVA_VER=$(java -version 2>&1 >/dev/null | egrep "\S+\s+version" | awk '{print $3}' | tr -d '"')
		case "${JAVA_VER}" in 
			1[1-9].*.*)
				echo "done" >> ${LOGFILE}
				;;
			*)
				echo " "
				echo "Error: Hyperfoil requires Java 11 or newer and current java version is ${JAVA_VER}"
				exit 1
				;;
		esac
	fi
}

# Check for all the prereqs
function check_prereq() {
	docker version > ${LOGFILE} 2>&1
	err_exit "Error: docker not installed \nInstall docker and try again."
}

# Get the IP addr of the machine / vm that we are running on
function get_ip() {
	IP_ADDR=$(ip addr | grep "global" | grep "dynamic" | awk '{ print $2 }' | cut -f 1 -d '/')
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(ip addr | grep "global" | head -1 | awk '{ print $2 }' | cut -f 1 -d '/')
	fi
}

# Check if the application is running
# output: Returns 1 if the application is running else returns 0
function check_app() {
	if [ "${CLUSTER_TYPE}" == "openshift" ]; then
		CMD=$(oc get pods --namespace=${NAMESPACE} | grep "tfb-qrh" | grep "Running" | cut -d " " -f1)
	fi
	for status in "${CMD[@]}"
	do
		if [ -z "${status}" ]; then
			#echo "Application pod did not come up"
			# Wait for 60sec more and check again before exiting
			sleep 60
			CMD=$(oc get pods --namespace=${NAMESPACE} | grep "tfb-qrh" | grep "Running" | cut -d " " -f1)
			status1=${CMD[@]}
			if [ -z "${status1}" ]; then
				echo "Application pod did not come up"
				exit -1;
			fi
		fi
	done
}

# Parse the Throughput Results
# input:result directory , Number of iterations of the wrk load
# output:Throughput log file (tranfer per sec, Number of requests per second, average latency and errors if any)
function parse_tfb_results() {
	RESULTS_DIR=$1
	TOTAL_LOGS=$2
	echo "RUN, THROUGHPUT, RESPONSE_TIME, MAX_RESPONSE_TIME, STDDEV_RESPONSE_TIME, ERRORS" > ${RESULTS_DIR}/Throughput.log
	for (( iteration=1 ; iteration<=${TOTAL_LOGS} ;iteration++))
	do
		RESULT_LOG=${RESULTS_DIR}/wrk-${inst}-${iteration}.log
		throughput=`cat ${RESULT_LOG} | grep "Requests" | cut -d ":" -f2 `
		responsetime=`cat ${RESULT_LOG} | grep "Latency" | cut -d ":" -f2 | tr -s " " | cut -d " " -f2 `
		max_responsetime=`cat ${RESULT_LOG} | grep "Latency" | cut -d ":" -f2 | tr -s " " | cut -d " " -f6 `
		stddev_responsetime=`cat ${RESULT_LOG} | grep "Latency" | cut -d ":" -f2 | tr -s " " | cut -d " " -f4 `
		weberrors=`cat ${RESULT_LOG} | grep "Non-2xx" | cut -d ":" -f2`
		if [ "${weberrors}" == "" ]; then
			weberrors="0"
		fi
		echo "${iteration},    ${throughput},     ${responsetime},         ${max_responsetime},             ${stddev_responsetime},             ${weberrors}" >> ${RESULTS_DIR}/Throughput.log
	done
}

# Download the required dependencies
# output: Check if the hyperfoil/wrk dependencies is already present, If not download the required dependencies to apply the load
function load_setup(){
	if [ ! -d "${PWD}/hyperfoil-0.13" ]; then
		wget https://github.com/Hyperfoil/Hyperfoil/releases/download/release-0.13/hyperfoil-0.13.zip >> ${LOGFILE} 2>&1
		unzip hyperfoil-0.13.zip 
	fi
	pushd hyperfoil-0.13/bin > /dev/null
}
