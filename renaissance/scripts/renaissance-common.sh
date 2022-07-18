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
RENAISSANCE_REPO="${CURRENT_DIR}"
BENCHMARK_IMAGE="prakalp23/renaissance1041:latest"
DEFAULT_NAMESPACE="default"
MANIFESTS_DIR="manifests/"
APP_NAME="renaissance"

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
## Forward the prometheus port to collect the metrics
function fwd_prometheus_port_minikube() {
	kubectl port-forward pod/prometheus-k8s-0 9090:9090 -n monitoring >> ${LOGFILE} 2>&1 &
}
