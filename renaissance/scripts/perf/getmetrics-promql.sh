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
		exit 1
	fi
}
function get_cpu()
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
#		echo "curl --silent -G -kH Authorization: Bearer ${TOKEN} --data-urlencode 'query=sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate) by (pod)' ${URL} "		 
	  curl --data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total[5m])) by (pod,namespace)' http://localhost:9090/api/v1/query | jq '[ .data.result[] |  [.metric.pod, .value[0], .value[1]|tostring]| join(";") ]' | grep "${APP_NAME}"| cut -d ";" -f2,3 >> ${RESULTS_DIR}/cpu-${ITER}.json
#err_exit "Error: could not get cpu details of the pod" >>setup.log
sleep 15
	done
}
## Collect MEM_RSS
function get_mem_rss()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/mem-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(container_memory_rss) by (pod)' http://localhost:9090/api/v1/query  | jq '[ .data.result[] | [ .metric.pod,.value[0], .value[1]|tostring]| join(";") ]' | grep "${APP_NAME}"| cut -d ";" -f2,3 >> ${RESULTS_DIR}/mem-${ITER}.json
		#err_exit "Error: could not get memory details of the pod" >>setup.log
		sleep 15
	done
}
function get_mem_usage()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/memusage-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(container_memory_working_set_bytes) by (pod) ' http://localhost:9090/api/v1/query  | jq '[ .data.result[] | [ .metric.pod,.value[0], .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}"|cut -d ";" -f2,3 >> ${RESULTS_DIR}/memusage-${ITER}.json
		#err_exit "Error: could not get memory details of the pod" >>setup.log
		sleep 15
	done
}
## Collect network bytes received
function get_container_network_receive_bytes_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_receive_bytes_total[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/netreceivebytes-${ITER}.json
				#err_exit "Error: could not get network received details of the pod" >>setup.log
				sleep 15
	done
}
function get_container_network_transmit_bytes_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_transmit_bytes_total[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/nettransmitbytes-${ITER}.json
		#err_exit "Error: could not get container network transmit bytes details of the pod" >>setup.log
		sleep 15
	done
}
function get_container_network_receive_packets_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_receive_packets_total[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cnetreceivebytes-${ITER}.json
		#err_exit "Error: could not get container network receive packet details of the pod" >>setup.log
		sleep 15
	done
}
function get_container_network_transmit_packets_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_transmit_packets_total[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/cnettransmitbytes-${ITER}.json
		#err_exit "Error: could not get container network tranmit packet  details of the pod" >>setup.log
		sleep 15
	done
}
function get_disk_details_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_fs_usage_bytes[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/diskdetails-${ITER}.json
		#err_exit "Error: could not get disk details of the pod" >>setup.log
		sleep 15
	done
}
function get_container_fs_io_time_seconds_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_fs_io_time_seconds_total[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/fsiototal-${ITER}.json
		#err_exit "Error: could not get I/O time details of the pod" >>setup.log
		sleep 15
	done
}
function get_container_fs_read_seconds_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_fs_read_seconds_total[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep -E "[0-9]" >> ${RESULTS_DIR}/fsreadtotal-${ITER}.json
		#err_exit "Error: could not get required details of the pod" >>setup.log
		sleep 15
	done
}
function get_container_fs_write_seconds_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_fs_write_seconds_total[60s]))' http://localhost:9090/api/v1/query | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]'| grep -E "[0-9]" >> ${RESULTS_DIR}/fswritetotal-${ITER}.json
		#err_exit "Error: could not get required details of the pod" >>setup.log
		sleep 15
	done
}
#this is not required for renaissance as of now,will be updated later
function get_request_duration_seconds_sum_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_request_duration_seconds_sum[60s])) by (pod)' | jq '[ .data.result[] | [ .value[0], .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" http://localhost:9090/api/v1/query >> ${RESULTS_DIR}/get_request_duration_seconds_sum_total-${ITER}.json
		#err_exit "Error: could not get request sum duration of seconds details of the pod" >>setup.log
		sleep 15
	done
}
function get_request_duration_seconds_count_total()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_request_duration_seconds_count[60s])) by (pod)'| jq '[ .data.result[] | [ .value[0], .value[1]|tostring]| join(";") ]' | grep "${APP_NAME}" http://localhost:9090/api/v1/query >> ${RESULTS_DIR}/get_request_duration_seconds_count_total-${ITER}.json
		#err_exit "Error: could not get request count details of the pod" >>setup.log
		sleep 15
	done
}
ITER=$1
TIMEOUT=$2
RESULTS_DIR=$3
BENCHMARK_SERVER=$4
APP_NAME=$5
CLUSTER_TYPE=$6

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
export -f err_exit get_cpu get_mem_rss get_mem_usage get_container_network_receive_bytes_total
export -f get_container_network_transmit_bytes_total get_container_network_receive_packets_total get_container_network_transmit_packets_total get_disk_details_total
export -f get_container_fs_io_time_seconds_total get_container_fs_read_seconds_total get_container_fs_write_seconds_total get_request_duration_seconds_sum_total get_request_duration_seconds_count_total
echo "Collecting metric data" >> setup.log
timeout ${TIMEOUT} bash -c  "get_cpu ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_mem_rss ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_mem_usage ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_container_network_receive_bytes_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_container_network_transmit_bytes_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_container_network_receive_packets_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_container_network_transmit_packets_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_disk_details_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_container_fs_io_time_seconds_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_container_fs_read_seconds_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_container_fs_write_seconds_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_request_duration_seconds_sum_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_request_duration_seconds_count_total ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
sleep ${TIMEOUT}
