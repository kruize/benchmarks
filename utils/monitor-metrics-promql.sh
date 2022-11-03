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

function cpu_metrics()
{
        URL=$1
        TOKEN=$2
        RESULTS_DIR=$3
        ITER=$4
        APP_NAME=$5
        DEPLOYMENT_NAME=$6
        CONTAINER_NAME=$7
        NAMESPACE=$8
	INTERVAL=$9

        while true
        do
                # Processing curl output "timestamp value" using jq tool.
		# cpu_request_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(kube_pod_container_resource_requests{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="cpu", unit="core"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_request_avg_container-${ITER}.json
		
		# cpu_request_sum_container
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(kube_pod_container_resource_requests{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="cpu", unit="core"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_request_sum_container-${ITER}.json

		# cpu_limit_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(kube_pod_container_resource_limits{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="cpu", unit="core"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_limit_avg_container-${ITER}.json
		# cpu_limit_sum_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(kube_pod_container_resource_limits{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="cpu", unit="core"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_limit_sum_container-${ITER}.json
		# cpu_usage_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(avg_over_time(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_usage_avg_container-${ITER}.json

		# cpu_usage_max_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=max(max_over_time(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_usage_max_container-${ITER}.json

		# cpu_usage_min_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=min(min_over_time(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_usage_min_container-${ITER}.json

		# cpu_throttle_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(rate(container_cpu_cfs_throttled_seconds_total{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cpu_throttle_avg_container-${ITER}.json

		sleep ${INTERVAL}
        done
}

function mem_metrics()
{
        URL=$1
        TOKEN=$2
        RESULTS_DIR=$3
        ITER=$4
        APP_NAME=$5
        DEPLOYMENT_NAME=$6
        CONTAINER_NAME=$7
        NAMESPACE=$8
	INTERVAL=$9

        # Delete the old json file if any
        rm -rf ${RESULTS_DIR}/mem_request_avg_container-${ITER}.json
        while true
        do
                # Processing curl output "timestamp value" using jq tool.
		# mem_request_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(kube_pod_container_resource_requests{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="memory", unit="byte"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_request_avg_container-${ITER}.json
		# mem_request_sum_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(kube_pod_container_resource_requests{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="memory", unit="byte"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_request_sum_container-${ITER}.json
		# mem_limit_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(kube_pod_container_resource_limits{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="memory", unit="byte"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_limit_avg_container-${ITER}.json
		# mem_limit_sum_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(kube_pod_container_resource_limits{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'", resource="memory", unit="byte"})' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_limit_sum_container-${ITER}.json
		# mem_usage_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(avg_over_time(container_memory_working_set_bytes{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_usage_avg_container-${ITER}.json
		# mem_usage_min_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=min(min_over_time(container_memory_working_set_bytes{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_usage_min_container-${ITER}.json
		# mem_usage_max_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=max(max_over_time(container_memory_working_set_bytes{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_usage_max_container-${ITER}.json
		# mem_rss_avg_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=avg(avg_over_time(container_memory_rss{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_rss_avg_container-${ITER}.json
	
		# mem_rss_min_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=min(min_over_time(container_memory_rss{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_rss_min_container-${ITER}.json

		# mem_rss_max_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=max(max_over_time(container_memory_rss{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_rss_max_container-${ITER}.json

		# mem_rss_max_container
                curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=rate(container_network_receive_bytes_total{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", container="'"${CONTAINER_NAME}"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"'])' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/mem_rss_max_container-${ITER}.json
                sleep ${INTERVAL}
        done
}

function load_metrics()
{
        URL=$1
        TOKEN=$2
        RESULTS_DIR=$3
        ITER=$4
        APP_NAME=$5
        DEPLOYMENT_NAME=$6
        CONTAINER_NAME=$7
        NAMESPACE=$8
	INTERVAL=$9

        while true
        do
		# network_avg_pod
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_receive_bytes_total{pod=~"'"${DEPLOYMENT_NAME}-[^-]*-[^-]*$"'", namespace="'"${NAMESPACE}"'"}['"${INTERVAL}"']))' ${URL} | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/network_avg_pod-${ITER}.json		
		sleep ${INTERVAL}
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
#INTERVAL=${10}
#DEPLOYMENT_NAME="tfb-qrh-sample-0"
#CONTAINER_NAME="tfb-server"
#NAMESPACE="autotune-tfb"
INTERVAL=5m

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

export -f err_exit cpu_metrics mem_metrics load_metrics


echo "Collecting metric data" >> setup.log
timeout ${TIMEOUT} bash -c  "cpu_metrics ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} ${DEPLOYMENT_NAME} ${CONTAINER_NAME} ${NAMESPACE} ${INTERVAL}" &
timeout ${TIMEOUT} bash -c  "mem_metrics ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} ${DEPLOYMENT_NAME} ${CONTAINER_NAME} ${NAMESPACE} ${INTERVAL}" &
timeout ${TIMEOUT} bash -c  "load_metrics ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} ${DEPLOYMENT_NAME} ${CONTAINER_NAME} ${NAMESPACE} ${INTERVAL}" &
sleep ${TIMEOUT}

