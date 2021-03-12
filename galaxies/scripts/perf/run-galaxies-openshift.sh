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
### Script to perform load test on multiple instances of galaxies on openshift###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
pushd "${CURRENT_DIR}" > /dev/null
pushd ".." > /dev/null
SCRIPT_REPO=${PWD}

CLUSTER_TYPE="openshift"
pushd ".." > /dev/null
HYPERFOIL_DIR="${PWD}/hyperfoil-0.13/bin"
GALAXIES_DEFAULT_IMAGE="dinogun/galaxies:1.2-jdk-11.0.10_9"

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo
		echo "See setup.log for more details"
		exit -1
	fi
}

# Run the benchmark as
# SCRIPT BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH WRK_LOAD_USERS WRK_LOAD_DURATION WARMUPS MEASURES
# Ex of ARGS : -s wobbled.os.fyre.ibm.com -e /galaxies/results -u 400 -d 300 -w 5 -m 3

# Describes the usage of the script
function usage() {
	echo
	echo "Usage: $0 -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-u WRK_LOAD_USERS] [-d WRK_LOAD_DURATION] [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-g GALAXIES_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] [-t THREAD] [-R REQUEST_RATE] [-d DURATION] [--connection=CONNECTIONS] [--env=ENV_VAR]"
	exit -1
}

# Check if java is installed and it is of version 11 or newer
function check_load_prereq() {
	echo
	echo -n "Info: Checking prerequisites..."
	# check if java exists
	if [ ! `which java` ]; then
		echo " "
		echo "Error: java is not installed."
		exit 1
	else
		JAVA_VER=$(java -version 2>&1 >/dev/null | egrep "\S+\s+version" | awk '{print $3}' | tr -d '"')
		case "${JAVA_VER}" in 
			1[1-9].*.*)
				echo "done"
				;;
			*)
				echo " "
				echo "Error: Hyperfoil requires Java 11 or newer and current java version is ${JAVA_VER}"
				exit 1
				;;
		esac
	fi
}

# Iterate through the commandline options
while getopts s:e:w:m:i:rg:n:t:R:d:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			iter=*)
				TOTAL_ITR=${OPTARG#*=}
				;;
			cpureq=*)
				CPU_REQ=${OPTARG#*=}
				;;
			memreq=*)
				MEM_REQ=${OPTARG#*=}
				;;
			cpulim=*)
				CPU_LIM=${OPTARG#*=}
				;;
			memlim=*)
				MEM_LIM=${OPTARG#*=}
				;;
			connection=*)
				CONNECTIONS=${OPTARG#*=}
				;;
			env=*)
				ENV_VAR=${OPTARG#*=}
				;;
			*)
		esac
		;;
	s)
		BENCHMARK_SERVER="${OPTARG}"
		;;
	e)
		RESULTS_DIR_PATH="${OPTARG}"	
		;;
	w)
		WARMUPS="${OPTARG}"		
		;;
	m)
		MEASURES="${OPTARG}"		
		;;
	i)
		TOTAL_INST="${OPTARG}"
		;;
	r)
		RE_DEPLOY="true"
		;;
	g)
		GALAXIES_IMAGE="${OPTARG}"		
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

if [[ -z "${BENCHMARK_SERVER}" || -z "${RESULTS_DIR_PATH}" ]]; then
	echo "Do set the variables - BENCHMARK_SERVER and RESULTS_DIR_PATH "
	usage
fi

if [ -z "${WARMUPS}" ]; then
	WARMUPS=5
fi

if [ -z "${MEASURES}" ]; then
	MEASURES=3
fi

if [ -z "${TOTAL_INST}" ]; then
	TOTAL_INST=1
fi

if [ -z "${TOTAL_ITR}" ]; then
	TOTAL_ITR=1
fi

if [ -z "${RE_DEPLOY}" ]; then
	RE_DEPLOY=false
fi

if [ -z "${GALAXIES_IMAGE}" ]; then
	GALAXIES_IMAGE="${GALAXIES_DEFAULT_IMAGE}"
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="openshift-monitoring"
fi

if [ -z "${REQUEST_RATE}" ]; then
	REQUEST_RATE="2000"
fi

if [ -z "${THREAD}" ]; then
	THREAD="40"
fi

if [ -z "${DURATION}" ]; then
	DURATION="60"
fi

if [ -z "${CONNECTIONS}" ]; then
	CONNECTIONS="700"
fi

# Check if the dependencies required to apply the load is present 
check_load_prereq 

# Check if the application is running
# output: Returns 1 if the application is running else returns 0
function check_app() {
	CMD=$(oc get pods --namespace=${NAMESPACE} | grep "galaxies" | grep "Running" | cut -d " " -f1)
	for status in "${CMD[@]}"
	do
		if [ -z "${status}" ]; then
			echo "Application pod did not come up" 
			exit -1;
		fi
	done
}

RESULTS_DIR_ROOT=${RESULTS_DIR_PATH}/galaxies-$(date +%Y%m%d%H%M)
mkdir -p ${RESULTS_DIR_ROOT}

#Adding 10 secs buffer to retrieve CPU and MEM info
CPU_MEM_DURATION=`expr ${DURATION} + 10`

throughputlogs=(throughput responsetime weberrorresponsetime_max stdev_resptime_max)
podcpulogs=(cpu cpurequests cpulimits cpureq_in_p cpulimits_in_p)
podmemlogs=(mem memusage memrequests memlimits memreq_in_p memlimit_in_p)
clusterlogs=(c_mem c_cpu c_cpulimits c_cpurequests c_memlimits c_memrequests)
total_logs=(${throughputlogs[@]} ${podcpulogs[@]} ${podmemlogs[@]} ${clusterlogs[@]} cpu_min cpu_max mem_min mem_max)

# Download the required dependencies 
# output: Check if the hyperfoil/wrk dependencies is already present, If not download the required dependencies to apply the load
function load_setup(){
	if [ ! -d "${PWD}/hyperfoil-0.13" ]; then
		wget https://github.com/Hyperfoil/Hyperfoil/releases/download/release-0.13/hyperfoil-0.13.zip >> setup.log 2>&1
		err_exit "Error: Could not download the dependencies"
		unzip hyperfoil-0.13.zip >> setup.log
	fi
}

# Run the wrk load
# input: machine IP address, Result log file 
# output: Run the wrk load on galaxies application and store the result in log file 
function run_wrk_workload() {
	# Store results in this file
	IP_ADDR=$1
	RESULTS_LOG=$2
	# Run the wrk load
	echo "Running wrk load with the following parameters" >> setup.log
	cmd="${HYPERFOIL_DIR}/wrk2.sh --threads=${THREAD} --connections=${CONNECTIONS} --duration=${DURATION}s --rate=${REQUEST_RATE} http://${IP_ADDR}/galaxies"
	echo "CMD = ${cmd}" >> setup.log
	sleep 30
	${cmd} > ${RESULTS_LOG}
	sleep 20
}

# Run the wrk load on each instace of the application
# input: Result directory, Type of run(warmup|measure), iteration number
# output: call the run_wrk_workload for each application service
function run_wrk_with_scaling()
{	
	RESULTS_DIR_J=$1
	TYPE=$2
	RUN=$3
	svc_apis=($(oc status --namespace=${NAMESPACE} | grep "galaxies" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	load_setup
	for svc_api  in "${svc_apis[@]}"
	do
		RESULT_LOG=${RESULTS_DIR_J}/wrk-${svc_api}-${TYPE}-${RUN}.log
		run_wrk_workload ${svc_api} ${RESULT_LOG} &
	done
}

# Parse the result log files
# input:Type of run(warmup|measure), total number of runs, total number of iteration
# output:Throughput log file(throghput, response time, total memory used by the pod, total cpu used by the pod, cluster memory usage in percentage,cluster cpu in percentage and web errors if any)
function parseData() {
	TYPE=$1
	TOTAL_RUNS=$2
	ITR=$3
	echo "${TYPE} Runs" >> ${RESULTS_DIR_J}/Throughput-${itr}.log
	for (( run=0 ; run<${TOTAL_RUNS} ;run++))
	do
		thrp_sum=0
		resp_sum=0
		wer_sum=0
		svc_apis=($(oc status --namespace=${NAMESPACE} | grep "galaxies" | grep port | cut -d " " -f1 | cut -d "/" -f3))
		for svc_api  in "${svc_apis[@]}"
		do
			RESULT_LOG=${RESULTS_DIR_P}/wrk-${svc_api}-${TYPE}-${run}.log
			throughput=`cat ${RESULT_LOG} | grep "Requests" | cut -d ":" -f2 `
			responsetime=`cat ${RESULT_LOG} | grep "Latency" | cut -d ":" -f2 | tr -s " " | cut -d " " -f2 `
			max_responsetime=`cat ${RESULT_LOG} | grep "Latency" | cut -d ":" -f2 | tr -s " " | cut -d " " -f6 `
			stddev_responsetime=`cat ${RESULT_LOG} | grep "Latency" | cut -d ":" -f2 | tr -s " " | cut -d " " -f4 `
			weberrors=`cat ${RESULT_LOG} | grep "Non-2xx" | cut -d ":" -f2`
			thrp_sum=$(echo ${thrp_sum}+${throughput} | bc)
			resp_sum=$(echo ${resp_sum}+${responsetime} | bc)
			if [ "${weberrors}" != "" ]; then
			        wer_sum=`expr ${wer_sum} + ${weberrors}`
			fi
		done
		echo "${run},${thrp_sum},${resp_sum},${wer_sum},${max_responsetime},${stddev_responsetime}" >> ${RESULTS_DIR_J}/Throughput-${TYPE}-${itr}.log
		echo "${run} , ${CPU_REQ} , ${MEM_REQ} , ${CPU_LIM} , ${MEM_LIM} , ${thrp_sum} , ${responsetime} , ${wer_sum} , ${max_responsetime} , ${stddev_responsetime}" >> ${RESULTS_DIR_J}/Throughput-${TYPE}-raw.log
	done
}

# Parse CPU, memeory and cluster information
# input:type of run(warmup|measure), total number of runs, iteration number
# output:Creates cpu, memory and cluster information in the form of log files for each run
function parseCpuMem()  {
	TYPE=$1
	TOTAL_RUNS=$2
	ITR=$3

	echo "${TYPE} Runs" >> ${RESULTS_DIR_J}/Mem-${itr}.log
	for (( run=0 ; run<${TOTAL_RUNS} ;run++))
	do
		for podcpulog in "${podcpulogs[@]}"
		do
			# Parsing CPU logs for pod
			parsePodCpuLog ${podcpulog} ${TYPE} ${run} ${ITR}
		done
		for podmemlog in "${podmemlogs[@]}"
		do
			# Parsing Mem logs for pod
			parsePodMemLog ${podmemlog} ${TYPE} ${run} ${ITR}
		done
		for clusterlog in "${clusterlogs[@]}"
		do
			# Parsing Cluster logs 
			parseClusterLog ${clusterlog} ${RESULTS_DIR_P}/${clusterlog}-${TYPE}-${run}.json ${clusterlog}-${TYPE}-${itr}.log
		done
	done
}

# Parsing CPU logs for pod
# input: podcpulogs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates cpu log for pod
function parsePodCpuLog()
{
	MODE=$1
	TYPE=$2
	run=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	cpu_sum=0
	cpu_min=0
	cpu_max=0
	t_nodes=($(oc get nodes | grep worker | cut -d " " -f1))
	for t_node in "${t_nodes[@]}"
	do
		CPU_LOG=${RESULTS_DIR_P}/${t_node}_${MODE}-${TYPE}-${run}.json
		run_pods=($(cat ${CPU_LOG} | cut -d ";" -f2 | sort | uniq))
		for run_pod in "${run_pods[@]}"
		do
			cat ${CPU_LOG} | grep ${run_pod} | cut -d ";" -f3 | cut -d '"' -f1 > ${RESULTS_DIR_P}/temp-cpu.log
			each_pod_cpu_avg=$( echo `calcAvg ${RESULTS_DIR_P}/temp-cpu.log | cut -d "=" -f2`  )
			each_pod_cpu_min=$( echo `calcMin ${RESULTS_DIR_P}/temp-cpu.log` )
			each_pod_cpu_max=$( echo `calcMax ${RESULTS_DIR_P}/temp-cpu.log` )
			cpu_sum=$(echo ${cpu_sum}+${each_pod_cpu_avg}| bc)
			cpu_min=$(echo ${cpu_min}+${each_pod_cpu_min}| bc)
			cpu_max=$(echo ${cpu_max}+${each_pod_cpu_max} | bc)
		done
	done
	echo "${run} , ${cpu_sum}, ${cpu_min} , ${cpu_max}" >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	echo ",${cpu_sum} , ${cpu_min} , ${cpu_max}" >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
}

# Parsing memory logs for pod
# input: podmemlogs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates memory log for pod
function parsePodMemLog()
{
	MODE=$1
	TYPE=$2
	run=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	mem_sum=0
	mem_min=0
	mem_max=0
	t_nodes=($(oc get nodes | grep worker | cut -d " " -f1))
	for t_node in "${t_nodes[@]}"
	do
		MEM_LOG=${RESULTS_DIR_P}/${t_node}_${MODE}-${TYPE}-${run}.json
		mem_pods=($(cat ${MEM_LOG} | cut -d ";" -f2 | sort | uniq))
		for mem_pod in "${mem_pods[@]}"
		do
			cat ${MEM_LOG} | grep ${mem_pod} | cut -d ";" -f3 | cut -d '"' -f1 > ${RESULTS_DIR_P}/temp-mem.log
			if [ ${MODE} ==  "memreq_in_p" ]  || [ ${MODE} ==  "memlimit_in_p" ]; then
				each_pod_mem_avg=$( echo `calcAvg_in_p ${RESULTS_DIR_P}/temp-mem.log | cut -d "=" -f2`  )
			else
				each_pod_mem_avg=$( echo `calcAvg_inMB ${RESULTS_DIR_P}/temp-mem.log | cut -d "=" -f2`  )
				each_pod_mem_min=$( echo `calcMin ${RESULTS_DIR_P}/temp-mem.log`  )
				each_pod_mem_min_inMB=$(echo ${each_pod_mem_min}/1024/1024 | bc)
				each_pod_mem_max=$( echo `calcMax ${RESULTS_DIR_P}/temp-mem.log`  )
				each_pod_mem_max_inMB=$(echo ${each_pod_mem_max}/1024/1024 | bc)
			fi
			mem_sum=$(echo ${mem_sum}+${each_pod_mem_avg} | bc)
			mem_min=$(echo ${mem_min}+${each_pod_mem_min_inMB} | bc)
			mem_max=$(echo ${mem_max}+${each_pod_mem_max_inMB} | bc)
		done
	done
	echo "${run} , ${mem_sum}, ${mem_min} , ${mem_max} " >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	echo ", ${mem_sum} , ${mem_min} , ${mem_max} " >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
}

# Parsing memory logs for pod
# input: clusterlogs array element, json file with cluster information, result log file
# output:creates clsuter log file
function parseClusterLog() {
	MODE=$1
	CLUSTER_LOG=$2
	CLUSTER_RESULTS_LOG=$3
	cat ${CLUSTER_LOG}| cut -d ";" -f2 | cut -d '"' -f1 | grep -Eo '[0-9\.]+' > C_temp.log
	cluster_cpumem=$( echo `calcAvg_in_p C_temp.log | cut -d "=" -f2`  )
	echo "${run} , ${cluster_cpumem}" >> ${RESULTS_DIR_J}/${CLUSTER_RESULTS_LOG}
}

# Parse the results of wrk load for each instance of application
# input: total number of iterations, result directory, Total number of instances
# output: Parse the results and generate the Metrics log files
function parseResults() {
	TOTAL_ITR=$1
	RESULTS_DIR_J=$2
	sca=$3
	for (( itr=0 ; itr<${TOTAL_ITR} ;itr++))
	do
		RESULTS_DIR_P=${RESULTS_DIR_J}/ITR-${itr}
		parseData warmup ${WARMUPS} ${itr}
		parseData measure ${MEASURES} ${itr}
		parseCpuMem warmup ${WARMUPS} ${itr}
		parseCpuMem measure ${MEASURES} ${itr}

		#Calculte Average and Median of Throughput, Memory and CPU  scores
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/throughput-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/responsetime-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/weberror-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f5 >> ${RESULTS_DIR_J}/responsetime_max-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f6 >> ${RESULTS_DIR_J}/stdev_resptime_max-measure-temp.log

		for podcpulog in "${podcpulogs[@]}"
		do
			cat ${RESULTS_DIR_J}/${podcpulog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podcpulog}-measure-temp.log
			cat ${RESULTS_DIR_J}/${podcpulog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podcpulog}_min-measure-temp.log
			cat ${RESULTS_DIR_J}/${podcpulog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podcpulog}_max-measure-temp.log
		done
		for podmemlog in "${podmemlogs[@]}"
		do
			cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podmemlog}-measure-temp.log
			cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podmemlog}_min-measure-temp.log
			cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podmemlog}_max-measure-temp.log
		done
		for clusterlog in "${clusterlogs[@]}"
		do
			cat ${RESULTS_DIR_J}/${clusterlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${clusterlog}-measure-temp.log
		done
		
		###### Add different raw logs we want to merge
		#Cumulative raw data
		paste ${RESULTS_DIR_J}/Throughput-measure-raw.log ${RESULTS_DIR_J}/cpu-measure-raw.log ${RESULTS_DIR_J}/mem-measure-raw.log >>  ${RESULTS_DIR_J}/../Metrics-raw.log
	done

	for metric in "${total_logs[@]}"
	do
		if [ ${metric} == "cpu_min" ] || [ ${metric} == "mem_min" ]; then
			minval=$(echo `calcMin ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
			eval total_${metric}=${minval}
		elif [ ${metric} == "cpu_max" ] || [ ${metric} == "mem_max" ] || [ ${metric} == "responsetime_max" ] || [ ${metric} == "stdev_resptime_max" ]; then
			maxval=$(echo `calcMax ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
			eval total_${metric}=${maxval}
		else
			val=$(echo `calcAvg ${RESULTS_DIR_J}/${metric}-measure-temp.log | cut -d "=" -f2`)
			eval total_${metric}_avg=${val}
		fi
	done

	echo "${sca} ,  ${total_throughput_avg} , ${total_responsetime_avg} , ${total_mem_avg} , ${total_cpu_avg} , ${total_cpu_min} , ${total_cpu_max} , ${total_mem_min} , ${total_mem_max} , ${total_c_mem_avg} , ${total_c_cpu_avg} , ${CPU_REQ} , ${MEM_REQ} , ${CPU_LIM} , ${MEM_LIM} , ${total_weberror_avg}, ${total_responsetime_max} , ${total_stdev_resptime_max} , ${quarkus_thread_pool_core_threads} , ${quarkus_thread_pool_queue_size=}  " >> ${RESULTS_DIR_J}/../Metrics.log
	echo "${sca} ,  ${total_mem_avg} , ${total_memusage_avg} , ${total_memrequests_avg} , ${total_memlimits_avg} , ${total_memreq_in_p_avg} , ${total_memlimit_in_p_avg} " >> ${RESULTS_DIR_J}/../Metrics-mem.log
	echo "${sca} ,  ${total_cpu_avg} , ${total_cpurequests_avg} , ${total_cpulimits_avg} , ${total_cpureq_in_p_avg} , ${total_cpulimits_in_p_avg} " >> ${RESULTS_DIR_J}/../Metrics-cpu.log
	echo "${sca} , ${total_c_cpu_avg} , ${total_c_cpurequests_avg} , ${total_c_cpulimits_avg} , ${total_c_mem_avg} , ${total_c_memrequests_avg} , ${total_c_memlimits_avg} " >> ${RESULTS_DIR_J}/../Metrics-cluster.log
}

# Calculate average in MB
# input: Result directory
# output: Average in MB
function calcAvg_inMB()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		awk '{sum+=$1} END { print "  Average =",sum/NR/1024/1024}' ${LOG} ;
	fi
}

# Calculate average in percentage
# input: Result directory
# output: Average in percentage
function calcAvg_in_p()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		awk '{sum+=$1} END { print " % Average =",sum/NR*100}' ${LOG} ;
	fi
}

# Calculate average
# input: Result directory
# output: Average
function calcAvg()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		awk '{sum+=$1} END { print "  Average =",sum/NR}' ${LOG} ;
	fi
}

#Calculate Median
# input: Result directory
# output: Median
function calcMedian()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		sort -n ${LOG} | awk ' { a[i++]=$1; } END { x=int((i+1)/2); if (x < (i+1)/2) print "  Median =",(a[x-1]+a[x])/2; else print "  Median =",a[x-1]; }'
	fi
}

# Calculate minimum
# input: Result directory
# output: Minimum value
function calcMin()	
{
	LOG=$1
	if [ -s ${LOG} ]; then
		sort -n ${LOG} | head -1	
	fi
}

# Calculate maximum
# input: Result directory
# output: Maximum value
function calcMax() {
	LOG=$1
	if [ -s ${LOG} ]; then
		sort -n ${LOG} | tail -1	
	fi
}

# Perform warmup and measure runs
# input: number of runs(warmup|measure), result directory 
# output: Cpu info, memory info, node info, wrk load for each runs(warmup|measure) in the form of jason files
function runItr()
{
	TYPE=$1
	RUNS=$2
	RESULTS_runItr=$3
	for (( run=0; run<${RUNS}; run++ ))
	do
		# Check if the application is running
		check_app
		echo "##### ${TYPE} ${run}" >> setup.log
		# Get CPU and MEM info through prometheus queries
		${SCRIPT_REPO}/perf/getstats-openshift.sh ${TYPE}-${run} ${CPU_MEM_DURATION} ${RESULTS_runItr} ${BENCHMARK_SERVER} galaxies &
		# Run the wrk workload
		run_wrk_with_scaling ${RESULTS_runItr} ${TYPE} ${run}
		# Sleep till the wrk load completes
		sleep ${WRK_LOAD_DURATION}
		sleep 20
	done
}

# get the kruize recommendation for galaxies application
# input: result directory
# output: kruize recommendations for galaxies
function get_recommendations_from_kruize()
{
	TOKEN=`oc whoami --show-token`
	app_list=($(oc get deployments --namespace=${NAMESPACE} | grep "galaxies" | cut -d " " -f1))
	for app in "${app_list[@]}"
	do
		curl --silent -k -H "Authorization: Bearer ${TOKEN}" http://kruize-openshift-monitoring.apps.${BENCHMARK_SERVER}/recommendations?application_name=${app} > ${RESULTS_DIR_I}/${app}-recommendations.log
		err_exit "Error: could not generate the recommendations for galaxies"
	done
}

# Perform warmup and measure runs
# input: scaling instance, total number of iterations, warmups , measures , result directory
# output: Deploy the application if required, perform the runs and get the recommendations
function runIterations() {
	SCALING=$1
	TOTAL_ITR=$2
	WARMUPS=$3
	MEASURES=$4
	RESULTS_DIR_ITR=$5
	#IF we want to use array of users we can use this variable.
	USERS=${WRK_LOAD_USERS}
	for (( itr=0; itr<${TOTAL_ITR}; itr++ ))
	do
		if [ ${RE_DEPLOY} == "true" ]; then
			${SCRIPT_REPO}/galaxies-deploy-openshift.sh -s ${BENCHMARK_SERVER} -i ${SCALING} -g ${GALAXIES_IMAGE} --cpureq=${CPU_REQ} --memreq=${MEM_REQ} --cpulim=${CPU_LIM} --memlim=${MEM_LIM} --env=${ENV_VAR}>> setup.log 
			err_exit "Error: galaxies deployment failed"
		fi
		# Start the load
		RESULTS_DIR_I=${RESULTS_DIR_ITR}/ITR-${itr}
		echo "Running ${WARMUPS} warmups for ${USERS} users" >> setup.log
		# Perform warmup runs
		runItr warmup ${WARMUPS} ${RESULTS_DIR_I}
		echo "Running ${MEASURES} measures for ${USERS} users" >> setup.log
		# Perform measure runs
		runItr measure ${MEASURES} ${RESULTS_DIR_I}
		sleep 60
		# get the kruize recommendation for galaxies application
		# commenting for now as it is not required in all cases
		#get_recommendations_from_kruize ${RESULTS_DIR_I}
	done
}

#TODO Create a function on how many DB inst required for a server. For now,defaulting it to 1
# Scale the instances and run the iterations
echo "Instances , Throughput , Responsetime , MEM_MEAN , CPU_MEAN , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , CLUSTER_MEM% , CLUSTER_CPU% , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , WEB_ERRORS , RESPONSETIME_MAX , STDEV_RESPTIME_MAX" > ${RESULTS_DIR_ROOT}/Metrics.log
echo "Instances ,  MEM_RSS , MEM_USAGE , MEM_REQ , MEM_LIM , MEM_REQ_IN_P , MEM_LIM_IN_P " > ${RESULTS_DIR_ROOT}/Metrics-mem.log
echo "Instances ,  CPU_USAGE , CPU_REQ , CPU_LIM , CPU_REQ_IN_P , CPU_LIM_IN_P " > ${RESULTS_DIR_ROOT}/Metrics-cpu.log
echo "Instances , CLUSTER_CPU% , C_CPU_REQ% , C_CPU_LIM% , CLUSTER_MEM% , C_MEM_REQ% , C_MEM_LIM% " > ${RESULTS_DIR_ROOT}/Metrics-cluster.log
echo "Run , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , Throughput , Responsetime , WEB_ERRORS , Responsetime_MAX , stdev_responsetime_max , CPU , CPU_MIN , CPU_MAX , MEM , MEM_MIN , MEM_MAX" > ${RESULTS_DIR_ROOT}/Metrics-raw.log

for (( scale=1; scale<=${TOTAL_INST}; scale++ ))
do
	RESULTS_SC=${RESULTS_DIR_ROOT}/scale_${scale}
	echo "RESULTS DIRECTORY is " ${RESULTS_DIR_ROOT} >> setup.log  
	echo "Running the benchmark with ${scale}  instances with ${TOTAL_ITR} iterations having ${WARMUPS} warmups and ${MEASURES} measurements" >> setup.log
	# Perform warmup and measure runs
	runIterations ${scale} ${TOTAL_ITR} ${WARMUPS} ${MEASURES} ${RESULTS_SC}
	echo "Parsing results for ${scale} instances" >> setup.log
	# Parse the results
	parseResults ${TOTAL_ITR} ${RESULTS_SC} ${scale}
done

# Display the Metrics log file
cat ${RESULTS_DIR_ROOT}/Metrics.log
cat ${RESULTS_DIR_ROOT}/Metrics-raw.log
