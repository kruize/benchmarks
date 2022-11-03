#!/bin/bash
#
# Copyright (c) 2020, 2021 IBM Corporation, RedHat and others.
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
### Script to get pod and cluster information through prometheus queries###
#
# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero
function err_exit() 
{
	if [ $? != 0 ]; then
		printf "$*"
		echo 
		exit -1
	fi
}

## Collect CPU data
function cpu_request_avg_container()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/cpu-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(kube_pod_container_resource_requests{pod=~"${DEPLOYMENT_NAME}-[^-]*-[^-]*$", container="${CONTAINER_NAME}", namespace="${NAMESPACE}", resource="cpu", unit="core"})' ${URL} | jq  >> ${RESULTS_DIR}/cpu_request_avg_container-${ITER}.json
		err_exit "Error: could not get cpu details of the pod" >>setup.log
	done
}

ITER=$1
TIMEOUT=$2
RESULTS_DIR=$3
BENCHMARK_SERVER=$4
APP_NAME=$5
CLUSTER_TYPE=$6
DEPLOYMENT_NAME=$7
CONTAINER_NAME=$8
NAMESPACE=$9


mkdir -p ${RESULTS_DIR}
#QUERY_APP=prometheus-k8s-openshift-monitoring.apps
if [[ ${CLUSTER_TYPE} == "openshift" ]]; then
	QUERY_APP=thanos-querier-openshift-monitoring.apps
	URL=https://${QUERY_APP}.${BENCHMARK_SERVER}/api/v1/query
	TOKEN=`oc whoami --show-token`
elif [[ ${CLUSTER_TYPE} == "minikube" ]]; then
	#QUERY_IP=`minikibe ip`
	QUERY_APP="${BENCHMARK_SERVER}:9090"
	URL=http://${QUERY_APP}/api/v1/query
	TOKEN=TOKEN
fi

export -f cpu_request_avg_container

echo "Collecting metric data" >> setup.log
timeout ${TIMEOUT} bash -c  "cpu_request_avg_containe ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} ${DEPLOYMENT_NAME} ${CONTAINER_NAME} ${NAMESPACE}" &
sleep ${TIMEOUT}

