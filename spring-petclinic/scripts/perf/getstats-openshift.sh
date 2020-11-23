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
### Script to get pod and cluster information through prometheus queries###
#

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() 
{
	if [ $? != 0 ]; then
		printf "$*"
		echo "Error: could not get the details of pod"
		exit -1
	fi
}

# Get the memory details for pod
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the memory information for pod through prometheus query and store it in json file
function get_pod_mem_rss()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	echo "APP_NAME is ..." ${APP_NAME} >> setup.log
	rm -rf $RESULTS_DIR/${node}_mem-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool. 
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_rss{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_mem-$ITER.json
		err_exit 
	done
}

# Get the memory usage details for pod
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the memory usage information for pod through prometheus query and store it in json file
function get_pod_mem_usage()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_memusage-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_working_set_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memusage-$ITER.json
		err_exit "Error: could not get memory usage details of pod"
	done
}

# Get the memory request details for pod
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the memory request information for pod through prometheus query and store it in json file
function get_pod_mem_requests()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_memrequests-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_requests_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memrequests-$ITER.json
		err_exit "Error: could not get memory request details of pod"
	done
}

# Get the memory usage details for pod in percentage
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the memory usage information in percentage through prometheus query and store it in json file
function get_pod_mem_requests_in_p()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_memreq_in_p-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_working_set_bytes{node='\"$node\"'}) by (pod) / sum(kube_pod_container_resource_requests_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memreq_in_p-$ITER.json
		err_exit "Error: could not get memory request details of pod in percentage"
	done
}

# Get the memory limit details for pod
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the memory limit information for pod through prometheus query and store it in json file
function get_pod_mem_limits()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_memlimits-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_limits_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memlimits-$ITER.json
		err_exit "Error: could not get memory limit details of pod"
	done
}

# Get the memory limit details for pod in percentage
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the memory percentage information in percentage through prometheus query and store it in json file
function get_pod_mem_limits_in_p()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_memlimit_in_p-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_working_set_bytes{node='\"$node\"'}) by (pod) / sum(kube_pod_container_resource_limits_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memlimit_in_p-$ITER.json
		err_exit "Error: could not get memory limit details of pod in percentage"
	done
}

# Get the cpu usage details for pod
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the cpu usage information for pod through prometheus query and store it in json file
function get_pod_cpu_usage()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_cpu-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		#Get all pods data from 1 node using single command
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_cpu-$ITER.json
		err_exit "Error: could not get CPU usage details of pod"
	done
}

# Get the cpu request details for pod
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the cpu request information for pod through prometheus query and store it in json file
function get_pod_cpu_requests()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_cpurequests-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		#Get all pods data from 1 node using single command
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_requests_cpu_cores{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_cpurequests-$ITER.json
		err_exit "Error: could not get CPU request details of pod"
	done
}

# Get the cpu request details for pod in percentage
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the cpu request information in percentage through prometheus query and store it in json file
function get_pod_cpu_requests_in_p()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_cpureq_in_p-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		#Get all pods data from 1 node using single command
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{node='\"$node\"'}) by (pod) / sum(kube_pod_container_resource_requests_cpu_cores{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_cpureq_in_p-$ITER.json
		err_exit "Error: could not get CPU request details of pod in percentage"
	done
}

# Get the cpu limits details for pod
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the cpu limits information for pod through prometheus query and store it in json file
function get_pod_cpu_limits()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf  $RESULTS_DIR/${node}_cpulimits-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		#Get all pods data from 1 node using single command
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_limits_cpu_cores{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_cpulimits-$ITER.json
		err_exit "Error: could not get CPU limit details of pod"
	done
}

# Get the cpu limits details for pod in percentage
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the cpu limits information in percentage through prometheus query and store it in json file
function get_pod_cpu_limits_in_p()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	rm -rf $RESULTS_DIR/${node}_cpulimits_in_p-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		#Get all pods data from 1 node using single command
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{node='\"$node\"'}) by (pod) / sum(kube_pod_container_resource_limits_cpu_cores{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_cpulimits_in_p-$ITER.json
		err_exit "Error: could not get CPU limit details of pod in percentage"
	done
}

# Get the cluster information for pod 
# input:worker node, prometheus url, authorization token, result directory, application name
# output:generate the cluster information for pod through prometheus query and store it in json file
function get_cluster_info()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	rm -rf $RESULTS_DIR/cluster_cpu-$ITER.json $RESULTS_DIR/cluster_mem-$ITER.json $RESULTS_DIR/cluster_cpurequests-$ITER.json $RESULTS_DIR/cluster_cpulimits-$ITER.json $RESULTS_DIR/cluster_memrequests-$ITER.json $RESULTS_DIR/cluster_memlimits-$ITER.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		# Cluster MEm Usage
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=(1-sum(:node_memory_MemAvailable_bytes:sum) / sum(kube_node_status_allocatable_memory_bytes))' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_mem-$ITER.json
		err_exit "Error: could not get cluster memory usage details"
		
		# Cluster CPU Usage
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=(1-avg(rate(node_cpu_seconds_total{mode="idle"}[1m])))' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_cpu-$ITER.json
		err_exit "Error: could not get cluster CPU usage details"
		
		# CPU Requests COmmited
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_requests_cpu_cores) / sum(kube_node_status_allocatable_cpu_cores)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_cpurequests-$ITER.json
		err_exit "Error: could not get cluster CPU request details"
		
		# CPU Limits Commited
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_limits_cpu_cores) / sum(kube_node_status_allocatable_cpu_cores)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_cpulimits-$ITER.json
		err_exit "Error: could not get cluster CPU limits details"
		
		# Mem Requests Commited
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_requests_memory_bytes) / sum(kube_node_status_allocatable_memory_bytes)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_memrequests-$ITER.json
		err_exit "Error: could not get cluster memory request details"
		
		# Mem Limits Commited
		curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_limits_memory_bytes) / sum(kube_node_status_allocatable_memory_bytes)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_memlimits-$ITER.json
		err_exit "Error: could not get cluster memory limits details"
	done
}

ITER=$1
TIMEOUT=$2
RESULTS_DIR=$3
mkdir -p $RESULTS_DIR

PROMETHEUS_APP=prometheus-k8s-openshift-monitoring.apps
BENCHMARK_SERVER=$4
APP_NAME=$5

URL=https://${PROMETHEUS_APP}.${BENCHMARK_SERVER}/api/v1/query
#URL=https://prometheus-k8s-openshift-monitoring.apps.${BENCHMARK_SERVER}/api/v1/query
TOKEN=`oc whoami --show-token`

worker_nodes=($(oc get nodes | grep worker | cut -d " " -f1))
#Need to export the function to enable timeout
export -f err_exit
export -f get_pod_mem_rss get_pod_mem_usage get_pod_mem_requests get_pod_mem_requests_in_p get_pod_mem_limits get_pod_mem_limits_in_p
export -f get_pod_cpu_usage get_pod_cpu_requests get_pod_cpu_requests_in_p get_pod_cpu_limits get_pod_cpu_limits_in_p
export -f get_cluster_info

for i in "${worker_nodes[@]}"
do
	echo "Collecting CPU & MEM details of nodes $i  and cluster" >> setup.log
	timeout $TIMEOUT bash -c  "get_pod_mem_rss $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_cpu_usage $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_cluster_info $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &

	timeout $TIMEOUT bash -c  "get_pod_mem_usage $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_mem_requests $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_mem_requests_in_p $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_mem_limits $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_mem_limits_in_p $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	
	timeout $TIMEOUT bash -c  "get_pod_cpu_requests $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_cpu_requests_in_p $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_cpu_limits $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
	timeout $TIMEOUT bash -c  "get_pod_cpu_limits_in_p $i $URL $TOKEN $RESULTS_DIR $ITER $APP_NAME" &
done

