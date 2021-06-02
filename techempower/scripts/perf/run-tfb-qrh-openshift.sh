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
### Script to perform load test on multiple instances of tfb-qrh on openshift###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
pushd "${CURRENT_DIR}" > /dev/null
pushd ".." > /dev/null
SCRIPT_REPO=${PWD}

CLUSTER_TYPE="openshift"
pushd ".." > /dev/null
HYPERFOIL_DIR="${PWD}/hyperfoil-0.13/bin"
TFB_DEFAULT_IMAGE="kusumach/tfb.quarkus.resteasy.hibernate.mm1"

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo
		echo "See setup.log for more details"
		echo "1 , 99999 , 99999 , 99999 , 99999 , 99999 , 999999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 0 , 0 , 0 , 0" >> ${RESULTS_DIR_ROOT}/Metrics-prom.log
		echo ", 99999 , 99999 , 99999 , 99999 , 9999 , 0 , 0" >> ${RESULTS_DIR_ROOT}/Metrics-wrk.log
		paste ${RESULTS_DIR_ROOT}/Metrics-prom.log ${RESULTS_DIR_ROOT}/Metrics-wrk.log ${RESULTS_DIR_ROOT}/Metrics-config.log
		cat ${RESULTS_DIR_ROOT}/app-calc-metrics-measure-raw.log
		cat ${RESULTS_DIR_ROOT}/server_requests-metrics-${TYPE}-raw.log
		exit -1
	fi
}

# Run the benchmark as
# SCRIPT BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH WARMUPS MEASURES TOTAL_INST TOTAL_ITR RE_DEPLOY
# Ex of ARGS : -s example.in.com -e /tfb/results -w 5 -m 3 -i 1 --iter=1 -r

# Describes the usage of the script
function usage() {
	echo
	echo "Usage: $0 -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-g TFB_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] [-t THREAD] [-R REQUEST_RATE] [-d DURATION] [--connection=CONNECTIONS]"
	exit -1
}

# Check if java is installed and it is of version 11 or newer
function check_load_prereq() {
	echo
	echo -n "Info: Checking prerequisites..." >> setup.log
	# check if java exists
	if [ ! `which java` ]; then
		echo " "
		echo "Error: java is not installed."
		exit 1
	else
		JAVA_VER=$(java -version 2>&1 >/dev/null | egrep "\S+\s+version" | awk '{print $3}' | tr -d '"')
		case "${JAVA_VER}" in 
			1[1-9].*.*)
				echo "done" >> setup.log
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
			maxinlinelevel=*)
				maxinlinelevel=${OPTARG#*=}
				;;
			quarkustpcorethreads=*)
				quarkustpcorethreads=${OPTARG#*=}
                                ;;
			quarkustpqueuesize=*)
				quarkustpqueuesize=${OPTARG#*=}
                                ;;
			quarkusdatasourcejdbcminsize=*)
				quarkusdatasourcejdbcminsize=${OPTARG#*=}
                                ;;
			quarkusdatasourcejdbcmaxsize=*)
				quarkusdatasourcejdbcmaxsize=${OPTARG#*=}
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
		TFB_IMAGE="${OPTARG}"		
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

if [ -z "${TFB_IMAGE}" ]; then
	TFB_IMAGE="${TFB_DEFAULT_IMAGE}"
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="default"
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
	CMD=$(oc get pods --namespace=${NAMESPACE} | grep "tfb-qrh" | grep "Running" | cut -d " " -f1)
	for status in "${CMD[@]}"
	do
		if [ -z "${status}" ]; then
		#	echo "Application pod did not come up" 
			# Wait for 60sec more and check again before exiting
			sleep 60
			CMD=$(oc get pods --namespace=${NAMESPACE} | grep "tfb-qrh" | grep "Running" | cut -d " " -f1)
			status1=${CMD[@]}
                	if [ -z "${status1}" ]; then
	                	echo "Application pod did not come up" >> setup.log
				echo "1 , 99999 , 99999 , 99999 , 99999 , 99999 , 999999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 0 , 0" >> ${RESULTS_DIR_ROOT}/Metrics-prom.log
				echo ", 99999 , 99999 , 99999 , 99999 , 9999 , 0 , 0" >> ${RESULTS_DIR_ROOT}/Metrics-wrk.log
				paste ${RESULTS_DIR_ROOT}/Metrics-prom.log ${RESULTS_DIR_ROOT}/Metrics-wrk.log ${RESULTS_DIR_ROOT}/Metrics-config.log	
				exit -1;
        	        fi
#			exit -1;
		fi
	done
}

RESULTS_DIR_ROOT=${RESULTS_DIR_PATH}/tfb-$(date +%Y%m%d%H%M)
mkdir -p ${RESULTS_DIR_ROOT}

#Adding 5 secs buffer to retrieve CPU and MEM info
CPU_MEM_DURATION=`expr ${DURATION} + 5`

throughputlogs=(throughput responsetime weberror responsetime_max stdev_resptime_max)
podcpulogs=(cpu)
podmemlogs=(mem memusage)
clusterlogs=(c_mem c_cpu)
total_logs=(${throughputlogs[@]} ${podcpulogs[@]} ${podmemlogs[@]} cpu_min cpu_max mem_min mem_max)

# Download the required dependencies 
# output: Check if the hyperfoil/wrk dependencies is already present, If not download the required dependencies to apply the load
function load_setup(){
	if [ ! -d "${PWD}/hyperfoil-0.13" ]; then
		wget https://github.com/Hyperfoil/Hyperfoil/releases/download/release-0.13/hyperfoil-0.13.zip >> setup.log 2>&1
		err_exit "Error: Could not download the dependencies" >> setup.log
		unzip hyperfoil-0.13.zip >> setup.log
	fi
}

# Run the wrk load
# input: machine IP address, Result log file 
# output: Run the wrk load on tfb application and store the result in log file 
function run_wrk_workload() {
	# Store results in this file
	IP_ADDR=$1
	RESULTS_LOG=$2
	# Run the wrk load
	echo "Running wrk load with the following parameters" >> setup.log
	cmd="${HYPERFOIL_DIR}/wrk2.sh --latency --threads=${THREAD} --connections=${CONNECTIONS} --duration=${DURATION}s --rate=${REQUEST_RATE} http://${IP_ADDR}/db"
	echo "CMD = ${cmd}" >> setup.log
	#sleep 30
	${cmd} > ${RESULTS_LOG}
	sleep 1
}

# Run the wrk load on each instace of the application
# input: Result directory, Type of run(warmup|measure), iteration number
# output: call the run_wrk_workload for each application service
function run_wrk_with_scaling()
{	
	RESULTS_DIR_J=$1
	TYPE=$2
	RUN=$3
	svc_apis=($(oc status --namespace=${NAMESPACE} | grep "tfb-qrh" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	load_setup
	for svc_api  in "${svc_apis[@]}"
	do
		RESULT_LOG=${RESULTS_DIR_J}/wrk-${svc_api}-${TYPE}-${RUN}.log
		run_wrk_workload ${svc_api} ${RESULT_LOG} &
	done
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
		${SCRIPT_REPO}/perf/getmetrics-promql.sh ${TYPE}-${run} ${CPU_MEM_DURATION} ${RESULTS_runItr} ${BENCHMARK_SERVER} tfb-qrh &
		# Run the wrk workload
		run_wrk_with_scaling ${RESULTS_runItr} ${TYPE} ${run}
		# Sleep till the wrk load completes
		sleep ${DURATION}
		sleep 1
	done
}

# get the kruize recommendation for tfb application
# input: result directory
# output: kruize recommendations for tfb
function get_recommendations_from_kruize()
{
	TOKEN=`oc whoami --show-token`
	app_list=($(oc get deployments --namespace=${NAMESPACE} | grep "tfb-qrh" | cut -d " " -f1))
	for app in "${app_list[@]}"
	do
		curl --silent -k -H "Authorization: Bearer ${TOKEN}" http://kruize-openshift-monitoring.apps.${BENCHMARK_SERVER}/recommendations?application_name=${app} > ${RESULTS_DIR_I}/${app}-recommendations.log
		err_exit "Error: could not generate the recommendations for tfb-qrh" >> setup.log
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
	for (( itr=0; itr<${TOTAL_ITR}; itr++ ))
	do
		if [ ${RE_DEPLOY} == "true" ]; then
			${SCRIPT_REPO}/tfb-qrh-deploy-openshift.sh -s ${BENCHMARK_SERVER} -i ${SCALING} -g ${TFB_IMAGE} --cpureq=${CPU_REQ} --memreq=${MEM_REQ} --cpulim=${CPU_LIM} --memlim=${MEM_LIM} --maxinlinelevel=${maxinlinelevel} --quarkustpcorethreads=${quarkustpcorethreads} --quarkustpqueuesize=${quarkustpqueuesize} --quarkusdatasourcejdbcminsize=${quarkusdatasourcejdbcminsize} --quarkusdatasourcejdbcmaxsize=${quarkusdatasourcejdbcmaxsize} >> setup.log 
			# err_exit "Error: tfb-qrh deployment failed" >> setup.log
		fi
		# Start the load
		RESULTS_DIR_I=${RESULTS_DIR_ITR}/ITR-${itr}
		echo "Running ${WARMUPS} warmups" >> setup.log
		# Perform warmup runs
		runItr warmup ${WARMUPS} ${RESULTS_DIR_I}
		echo "Running ${MEASURES} measures" >> setup.log
		# Perform measure runs
		runItr measure ${MEASURES} ${RESULTS_DIR_I}
		sleep 5
		# get the kruize recommendation for tfb application
		# commenting for now as it is not required in all cases
		#get_recommendations_from_kruize ${RESULTS_DIR_I}
	done
}

#TODO Create a function on how many DB inst required for a server. For now,defaulting it to 1
# Scale the instances and run the iterations

echo "Instances , Throughput , Responsetime , RESPONSETIME_MAX , STDEV_RESPTIME_MAX , MEM_MEAN , CPU_MEAN , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , CLUSTER_MEM% , CLUSTER_CPU% , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , maxinlinelevel , quarkustpcorethreads , quarkustpqueuesize , quarkusdatasourcejdbcminsize , quarkusdatasourcejdbcmaxsize , WEB_ERRORS" > ${RESULTS_DIR_ROOT}/Metrics.log
echo ", CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , maxinlinelevel , quarkustpcorethreads , quarkustpqueuesize , quarkusdatasourcejdbcminsize , quarkusdatasourcejdbcmaxsize" > ${RESULTS_DIR_ROOT}/Metrics-config.log
echo ", Throughput , Responsetime , RESPONSETIME_MAX , STDEV_RESPTIME_MAX , WEB_ERRORS , thrp_wrk_ci , rsp_wrk_ci" > ${RESULTS_DIR_ROOT}/Metrics-wrk.log
echo "Instances ,  MEM_RSS , MEM_USAGE , MEM_REQ , MEM_LIM , MEM_REQ_IN_P , MEM_LIM_IN_P " > ${RESULTS_DIR_ROOT}/Metrics-mem.log
echo "Instances ,  CPU_USAGE , CPU_REQ , CPU_LIM , CPU_REQ_IN_P , CPU_LIM_IN_P " > ${RESULTS_DIR_ROOT}/Metrics-cpu.log
echo "Instances , CLUSTER_CPU% , C_CPU_REQ% , C_CPU_LIM% , CLUSTER_MEM% , C_MEM_REQ% , C_MEM_LIM% " > ${RESULTS_DIR_ROOT}/Metrics-cluster.log
echo "Run , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , Throughput , Responsetime , WEB_ERRORS , Responsetime_MAX , stdev_responsetime_max , CPU , CPU_MIN , CPU_MAX , MEM , MEM_MIN , MEM_MAX" > ${RESULTS_DIR_ROOT}/Metrics-raw.log

echo "SCALE ,  THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m , MAX_RESPONSE_TIME , APP_THROUGHPUT_RATE_3m , APP_RESPONSE_TIME_RATE_3m , APP_MAX_RESPONSE_TIME , RESPONSE_TIME_50p , RESPONSE_TIME_95p , RESPONSE_TIME_98p , RESPONSE_TIME_99p , RESPONSE_TIME_999p , MEM_USAGE , CPU_USAGE , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , thrpt_prom_ci , rsp_prom_ci , app_thrpt_prom_ci , app_rsp_prom_ci" > ${RESULTS_DIR_ROOT}/Metrics-prom.log
echo "SCALE ,  THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m , THROUGHPUT , RESPONSE_TIME , MAX_RESPONSE_TIME , APP_THROUGHPUT_RATE_3m , APP_RESPONSE_TIME_RATE_3m , APP_THROUGHPUT , APP_RESPONSE_TIME , APP_MAX_RESPONSE_TIME , RESPONSE_TIME_50p , RESPONSE_TIME_95p , RESPONSE_TIME_98p , RESPONSE_TIME_99p , RESPONSE_TIME_999p , MEM_USAGE , CPU_USAGE , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , thrpt_prom_ci , rsp_prom_ci , app_thrpt_prom_ci , app_rsp_prom_ci" > ${RESULTS_DIR_ROOT}/Metrics-prom-all.log
echo "SCALE ,  MEM_RSS , MEM_USAGE " > ${RESULTS_DIR_ROOT}/Metrics-mem-prom.log
echo "SCALE ,  CPU_USAGE" > ${RESULTS_DIR_ROOT}/Metrics-cpu-prom.log
echo ", 50p , 95p , 98p , 99p , 99.9p" > ${RESULTS_DIR_ROOT}/Metrics-percentile-prom.log
echo "ITR , APP_THROUGHPUT , APP_RESPONSE_TIME , APP_THROUGHPUT_RATE_3m , APP_RESPONSE_TIME_RATE_3m" >> ${RESULTS_DIR_ROOT}/app-calc-metrics-measure-raw.log
echo "ITR , THROUGHPUT , RESPONSE_TIME , THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m" >> ${RESULTS_DIR_ROOT}/server_requests-metrics-measure-raw.log
echo "THROUGHPUT_RATE_1m , RESPONSE_TIME_RATE_1m , THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m , THROUGHPUT_RATE_5m , RESPONSE_TIME_RATE_5m , THROUGHPUT_RATE_7m , RESPONSE_TIME_RATE_7m , THROUGHPUT_RATE_9m , RESPONSE_TIME_RATE_9m , THROUGHPUT_RATE_15m , RESPONSE_TIME_RATE_15m , THROUGHPUT_RATE_30m , RESPONSE_TIME_RATE_30m " > ${RESULTS_DIR_ROOT}/Metrics-rate-prom.log

echo ", ${CPU_REQ} , ${MEM_REQ} , ${CPU_LIM} , ${MEM_LIM} , ${maxinlinelevel} , ${quarkustpcorethreads} , ${quarkustpqueuesize} , ${quarkusdatasourcejdbcminsize} , ${quarkusdatasourcejdbcmaxsize}" >> ${RESULTS_DIR_ROOT}/Metrics-config.log

for (( scale=1; scale<=${TOTAL_INST}; scale++ ))
do
	RESULTS_SC=${RESULTS_DIR_ROOT}/scale_${scale}
	echo "RESULTS DIRECTORY is " ${RESULTS_DIR_ROOT} >> setup.log  
	echo "Running the benchmark with ${scale}  instances with ${TOTAL_ITR} iterations having ${WARMUPS} warmups and ${MEASURES} measurements" >> setup.log
	# Perform warmup and measure runs
	runIterations ${scale} ${TOTAL_ITR} ${WARMUPS} ${MEASURES} ${RESULTS_SC}
	echo "Parsing results for ${scale} instances" >> setup.log
	# Parse the results
	${SCRIPT_REPO}/perf/parsemetrics-promql.sh ${TOTAL_ITR} ${RESULTS_SC} ${scale} ${WARMUPS} ${MEASURES} ${SCRIPT_REPO}
	sleep 3
	${SCRIPT_REPO}/perf/parsemetrics-wrk.sh ${TOTAL_ITR} ${RESULTS_SC} ${scale} ${WARMUPS} ${MEASURES} ${SCRIPT_REPO}
done

# Display the Metrics log file
paste ${RESULTS_DIR_ROOT}/Metrics-prom.log ${RESULTS_DIR_ROOT}/Metrics-wrk.log ${RESULTS_DIR_ROOT}/Metrics-config.log
#cat ${RESULTS_DIR_ROOT}/app-calc-metrics-measure-raw.log
#cat ${RESULTS_DIR_ROOT}/server_requests-metrics-${TYPE}-raw.log
