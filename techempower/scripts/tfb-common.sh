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
export NETWORK="kruize-network"
LOGFILE="${PWD}/setup.log"
TFB_REPO="${CURRENT_DIR}"
TFB_DEFAULT_IMAGE="kruize/tfb-qrh:1.13.2.F_mm.v1"
DEFAULT_NAMESPACE="default"
DEFAULT_DB_TYPE="docker"
MANIFESTS_DIR="manifests/default_manifests"
HYPERFOIL_VERSION="0.25.2"
HYPERFOIL_DIR="${PWD}/hyperfoil-${HYPERFOIL_VERSION}/bin"
APP_NAME="tfb-qrh"
APP_DB="tfb-database"

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
		K_EXEC="oc"
	elif [ "${CLUSTER_TYPE}" == "minikube" ]; then
                K_EXEC="kubectl"
	fi
	CMD=$(${K_EXEC} get pods --namespace=${NAMESPACE} | grep "${APP_NAME}" | grep "Running" | cut -d " " -f1)
        for status in "${CMD[@]}"
        do
                if [ -z "${status}" ]; then
                        echo "Application pod did not come up" >> ${LOGFILE}
                        ${K_EXEC} get pods -n ${NAMESPACE} >> ${LOGFILE}
                        ${K_EXEC} get events -n ${NAMESPACE} >> ${LOGFILE}
                        ${K_EXEC} logs pod/`${K_EXEC} get pods | grep "${APP_NAME}" | cut -d " " -f1` -n ${NAMESPACE} >> ${LOGFILE}
                        echo "The run failed. See setup.log for more details"
                        exit -1;
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
		responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f2 `
		max_responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f6 `
		stddev_responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f4 `
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
	if [ ! -d "${PWD}/hyperfoil-${HYPERFOIL_VERSION}" ]; then
		wget https://github.com/Hyperfoil/Hyperfoil/releases/download/hyperfoil-all-${HYPERFOIL_VERSION}/hyperfoil-${HYPERFOIL_VERSION}.zip >> ${LOGFILE} 2>&1
		unzip hyperfoil-${HYPERFOIL_VERSION}.zip 
	fi
	pushd hyperfoil-${HYPERFOIL_VERSION}/bin > /dev/null
}

# Start/Stop the minikube
function reload_minikube(){
	cpus=$1
	memory=$2
	is_running=`minikube status | grep "host" | cut -d ":" -f2`
	if [[ ${is_running} == *"Running"* ]]; then
		minikube stop
		err_exit "Error: Unable to stop the minikube."
	fi
	minikube delete
	echo "starting with --cpus ${cpus} --memory ${memory}"
	minikube start --driver=kvm2 --cpus ${cpus} --memory ${memory}
	err_exit "Unable to start minikube with ${cpus} cpus and ${memory} memory"
}

## Forward the prometheus port to collect the metrics
function fwd_prometheus_port_minikube() {
	kubectl port-forward pod/prometheus-k8s-0 9090:9090 -n monitoring >> ${LOGFILE} 2>&1 &
}

## Create json output to support HPO wrapper
function createoutputcsv() {
	   "deployment_name": row[DEPLOYMENT_NAME],
            "namespace": row[NAMESPACE],
                "image_name": row[IMAGE_NAME],
                "container_name": row[CONTAINER_NAME],
                            "score": row[CPU_MEAN],
                            "mean": row[CPU_MEAN],
                            "min": row[CPU_MIN],
                            "max": row[CPU_MAX]
                            "score" : row[MEM_MEAN],
                            "mean" : row[MEM_MEAN],
                            "min" : row[MEM_MIN],
                            "max" : row[MEM_MAX]
                        "score": row[RQSUM_MEAN],
                        "mean" : row[RQSUM_MEAN],
                        "max" : row[RQSUM_MAX]
                        "50p": row[RQ_50p],
                        "95p": row[RQ_95p],
                        "97p": row[RQ_97p],
                        "99p": row[RQ_99p],
                        "99.9p": row[RQ_99.9p],
                        "99.99p": row[RQ_99.99p],
                        "99.999p": row[RQ_99.999p],
                        "100p": row[RQ_100p]
                        "score": row[RQC_MEAN],
                        "score": row[RQ_MAX]
}
