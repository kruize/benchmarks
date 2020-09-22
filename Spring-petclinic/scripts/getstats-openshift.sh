#!/bin/bash

function get_pod_mem_rss()
{
	node=$1
	URL=$2
	TOKEN=$3
	RESULTS_DIR=$4
	ITER=$5
	APP_NAME=$6
	# Delete the old json file if any
	echo "APP_NAME is ..." ${APP_NAME}
	rm -rf $RESULTS_DIR/${node}_mem-$ITER.json
	while true
	do
	# Processing curl output "timestamp value" using jq tool. 
	#TODO curl picks data of only 7 points for 10 seconds. Need to check if we can improve on this.
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_rss{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_mem-$ITER.json
	done
}

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
	#TODO curl picks data of only 7 points for 10 seconds. Need to check if we can improve on this.
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_working_set_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memusage-$ITER.json
	done
}

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
	#TODO curl picks data of only 7 points for 10 seconds. Need to check if we can improve on this.
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_requests_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memrequests-$ITER.json
	done
}

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
	#TODO curl picks data of only 7 points for 10 seconds. Need to check if we can improve on this.
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_working_set_bytes{node='\"$node\"'}) by (pod) / sum(kube_pod_container_resource_requests_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memreq_in_p-$ITER.json
	done
}

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
	#TODO curl picks data of only 7 points for 10 seconds. Need to check if we can improve on this.
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_limits_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memlimits-$ITER.json
	done
}

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
	#TODO curl picks data of only 7 points for 10 seconds. Need to check if we can improve on this.
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_working_set_bytes{node='\"$node\"'}) by (pod) / sum(kube_pod_container_resource_limits_memory_bytes{node='\"$node\"'}) by (pod)' $URL | jq '[ .data.result[] | [ .value[0], .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> $RESULTS_DIR/${node}_memlimit_in_p-$ITER.json
	done
}

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
	done
}

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
	done
}

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
	done
}

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
	done
}

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
	done
}

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
	# Cluster CPU Usage
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=(1-avg(rate(node_cpu_seconds_total{mode="idle"}[1m])))' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_cpu-$ITER.json
	# CPU Requests COmmited
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_requests_cpu_cores) / sum(kube_node_status_allocatable_cpu_cores)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_cpurequests-$ITER.json
	# CPU Limits Commited
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_limits_cpu_cores) / sum(kube_node_status_allocatable_cpu_cores)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_cpulimits-$ITER.json
	# Mem Requests Commited
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_requests_memory_bytes) / sum(kube_node_status_allocatable_memory_bytes)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_memrequests-$ITER.json
	# Mem Limits Commited
	curl --silent -G -kH "Authorization: Bearer $TOKEN" --data-urlencode 'query=sum(kube_pod_container_resource_limits_memory_bytes) / sum(kube_node_status_allocatable_memory_bytes)' $URL  | jq '[ .data.result[] | [ .value[0]  , .value[1]|tostring ] | join(";") ]' >> $RESULTS_DIR/c_memlimits-$ITER.json
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
#echo ${worker_nodes[@]}
#Need to export the function to enable timeout
export -f get_pod_mem_rss get_pod_mem_usage get_pod_mem_requests get_pod_mem_requests_in_p get_pod_mem_limits get_pod_mem_limits_in_p
export -f get_pod_cpu_usage get_pod_cpu_requests get_pod_cpu_requests_in_p get_pod_cpu_limits get_pod_cpu_limits_in_p
export -f get_cluster_info

for i in "${worker_nodes[@]}"
do
	echo "Collecting CPU & MEM details of nodes $i  and cluster"
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

