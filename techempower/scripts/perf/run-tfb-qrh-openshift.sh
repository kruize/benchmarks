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
source ${CURRENT_DIR}/../tfb-common.sh
pushd "${CURRENT_DIR}" > /dev/null
pushd ".." > /dev/null
SCRIPT_REPO=${PWD}
pushd ".." > /dev/null
LOGFILE="${PWD}/setup.log"
CLUSTER_TYPE="openshift"

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() {
	if [ $? != 0 ]; then
		printf "$*"
		echo
		echo "The run failed. See setup.log for more details"
		oc get pods -n ${NAMESPACE} >> ${LOGFILE}
		oc get events -n ${NAMESPACE} >> ${LOGFILE}
		oc logs pod/`oc get pods | grep "tfb-qrh" | cut -d " " -f1` -n ${NAMESPACE} >> ${LOGFILE}
		echo "1 , 99999 , 99999 , 99999 , 99999 , 99999 , 999999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999" >> ${RESULTS_DIR_ROOT}/Metrics-prom.log
		echo ", 99999 , 99999 , 99999 , 99999 , 9999 , 0 , 0" >> ${RESULTS_DIR_ROOT}/Metrics-wrk.log
		paste ${RESULTS_DIR_ROOT}/Metrics-prom.log ${RESULTS_DIR_ROOT}/Metrics-wrk.log ${RESULTS_DIR_ROOT}/Metrics-config.log
		cat ${RESULTS_DIR_ROOT}/app-calc-metrics-measure-raw.log
		cat ${RESULTS_DIR_ROOT}/server_requests-metrics-${TYPE}-raw.log
		## Cleanup all the deployments
		${SCRIPT_REPO}/tfb-cleanup.sh -c openshift -n ${NAMESPACE} >> ${LOGFILE}
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

# Iterate through the commandline options
while getopts s:e:w:m:i:rg:n:t:R:d:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			iter=*)
				TOTAL_ITR=${OPTARG#*=}
				;;
			dbtype=*)
				DB_TYPE=${OPTARG#*=}
				;;
			dbhost=*)
				DB_HOST=${OPTARG#*=}
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
			usertunables=*)
                                OPTIONS_VAR=${OPTARG#*=}
                                ;;
			connection=*)
				CONNECTIONS=${OPTARG#*=}
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
			FreqInlineSize=*)
                                FreqInlineSize=${OPTARG#*=}
                                ;;
                        MaxInlineLevel=*)
                                MaxInlineLevel=${OPTARG#*=}
                                ;;
                        MinInliningThreshold=*)
                                MinInliningThreshold=${OPTARG#*=}
                                ;;
                        CompileThreshold=*)
                                CompileThreshold=${OPTARG#*=}
                                ;;
                        CompileThresholdScaling=*)
                                CompileThresholdScaling=${OPTARG#*=}
                                ;;
                        InlineSmallCode=*)
                                InlineSmallCode=${OPTARG#*=}
                                ;;
                        LoopUnrollLimit=*)
                                LoopUnrollLimit=${OPTARG#*=}
                                ;;
                        LoopUnrollMin=*)
                                LoopUnrollMin=${OPTARG#*=}
                                ;;
                        MinSurvivorRatio=*)
                                MinSurvivorRatio=${OPTARG#*=}
                                ;;
                        NewRatio=*)
                                NewRatio=${OPTARG#*=}
                                ;;
                        TieredStopAtLevel=*)
                                TieredStopAtLevel=${OPTARG#*=}
                                ;;
                        ConcGCThreads=*)
                                ConcGCThreads=${OPTARG#*=}
                                ;;
                        TieredCompilation=*)
                                TieredCompilation=${OPTARG#*=}
                                ;;
                        AllowParallelDefineClass=*)
                                AllowParallelDefineClass=${OPTARG#*=}
                                ;;
                        AllowVectorizeOnDemand=*)
                                AllowVectorizeOnDemand=${OPTARG#*=}
				;;
                        AlwaysCompileLoopMethods=*)
                                AlwaysCompileLoopMethods=${OPTARG#*=}
                                ;;
                        AlwaysPreTouch=*)
                                AlwaysPreTouch=${OPTARG#*=}
                                ;;
                        AlwaysTenure=*)
                                AlwaysTenure=${OPTARG#*=}
                                ;;
                        BackgroundCompilation=*)
                                BackgroundCompilation=${OPTARG#*=}
                                ;;
                        DoEscapeAnalysis=*)
                                DoEscapeAnalysis=${OPTARG#*=}
                                ;;
                        UseInlineCaches=*)
                                UseInlineCaches=${OPTARG#*=}
                                ;;
                        UseLoopPredicate=*)
                                UseLoopPredicate=${OPTARG#*=}
                                ;;
                        UseStringDeduplication=*)
                                UseStringDeduplication=${OPTARG#*=}
                                ;;
                        UseSuperWord=*)
                                UseSuperWord=${OPTARG#*=}
                                ;;
                        UseTypeSpeculation=*)
                                UseTypeSpeculation=${OPTARG#*=}
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

RESULTS_DIR_ROOT=${RESULTS_DIR_PATH}/tfb-$(date +%Y%m%d%H%M)
mkdir -p ${RESULTS_DIR_ROOT}

#Adding 5 secs buffer to retrieve CPU and MEM info
CPU_MEM_DURATION=`expr ${DURATION} + 5`

# Check if the dependencies required to apply the load is present 
check_load_prereq 

# Add any debug logs required
function debug_logs() {
        for i in 0 1; do
                oc exec -n openshift-user-workload-monitoring prometheus-user-workload-${i} -c prometheus -- curl -s http://localhost:9090/api/v1/targets > ${RESULTS_DIR_ROOT}/targets.${i}.json
        done
}

# Check if the application is running
# output: Returns 1 if the application is running else returns 0
function check_app() {
	CMD=$(oc get pods --namespace=${NAMESPACE} | grep "tfb-qrh" | grep "Running" | cut -d " " -f1)
	for status in "${CMD[@]}"
	do
		if [ -z "${status}" ]; then
                	echo "Application pod did not come up" >> ${LOGFILE}
			oc get pods -n ${NAMESPACE} >> ${LOGFILE}
			oc get events -n ${NAMESPACE} >> ${LOGFILE}
			oc logs pod/`oc get pods | grep "tfb-qrh" | cut -d " " -f1` -n ${NAMESPACE} >> ${LOGFILE}
			echo "The run failed. See setup.log for more details"
			echo "1 , 99999 , 99999 , 99999 , 99999 , 99999 , 999999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999" >> ${RESULTS_DIR_ROOT}/Metrics-prom.log
			echo ", 99999 , 99999 , 99999 , 99999 , 9999 , 0 , 0" >> ${RESULTS_DIR_ROOT}/Metrics-wrk.log
			paste ${RESULTS_DIR_ROOT}/Metrics-prom.log ${RESULTS_DIR_ROOT}/Metrics-wrk.log ${RESULTS_DIR_ROOT}/Metrics-config.log	
			## Cleanup all the deployments
			${SCRIPT_REPO}/tfb-cleanup.sh -c openshift -n ${NAMESPACE} >> ${LOGFILE}
			exit -1;
		fi
	done
}

# Download the required dependencies 
# output: Check if the hyperfoil/wrk dependencies is already present, If not download the required dependencies to apply the load
function load_setup(){
	if [ ! -d "${SCRIPT_REPO}/hyperfoil-${HYPERFOIL_VERSION}" ]; then
		wget https://github.com/Hyperfoil/Hyperfoil/releases/download/release-${HYPERFOIL_VERSION}/hyperfoil-${HYPERFOIL_VERSION}.zip >> ${LOGFILE} 2>&1
		err_exit "Error: Could not download the dependencies" >> ${LOGFILE}
		unzip -o hyperfoil-${HYPERFOIL_VERSION}.zip -d ${SCRIPT_REPO} >> ${LOGFILE}
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
	echo "Running wrk load with the following parameters" >> ${LOGFILE}
#	cmd="${HYPERFOIL_DIR}/wrk2.sh --latency --threads=${THREAD} --connections=${CONNECTIONS} --duration=${DURATION}s --rate=${REQUEST_RATE} http://${IP_ADDR}/db"
	cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREAD} --connections=${CONNECTIONS} --duration=${DURATION}s http://${IP_ADDR}/db"
	echo "CMD = ${cmd}" >> ${LOGFILE}
	${cmd} > ${RESULTS_LOG}
	sleep 3
}

# Run the wrk load on each instace of the application
# input: Result directory, Type of run(warmup|measure), iteration number
# output: call the run_wrk_workload for each application service
function run_wrk_with_scaling()
{	
	TYPE=$1
	RUN=$2
	RESULTS_DIR_L=$3
	SVC_APIS=($(oc status --namespace=${NAMESPACE} | grep "tfb-qrh" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	load_setup
	for svc_api  in "${SVC_APIS[@]}"
	do
		RESULT_LOG=${RESULTS_DIR_L}/wrk-${svc_api}-${TYPE}-${RUN}.log
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
	RESULTS_DIR_L=$3
	for (( run=0; run<"${RUNS}"; run++ ))
	do
		# Check if the application is running
		check_app 
		# Get CPU and MEM info through prometheus queries
		${SCRIPT_REPO}/perf/getmetrics-promql.sh ${TYPE}-${run} ${CPU_MEM_DURATION} ${RESULTS_DIR_L} ${BENCHMARK_SERVER} tfb-qrh &
		# Run the wrk workload
		run_wrk_with_scaling ${TYPE} ${run} ${RESULTS_DIR_L}
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
	APP_LIST=($(oc get deployments --namespace=${NAMESPACE} | grep "tfb-qrh" | cut -d " " -f1))
	for app in "${APP_LIST[@]}"
	do
		curl --silent -k -H "Authorization: Bearer ${TOKEN}" http://kruize-openshift-monitoring.apps.${BENCHMARK_SERVER}/recommendations?application_name=${app} > ${RESULTS_DIR_I}/${app}-recommendations.log
		err_exit "Error: could not generate the recommendations for tfb-qrh" >> ${LOGFILE}
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
	RESULTS_DIR_R=$5
	for (( itr=0; itr<"${TOTAL_ITR}"; itr++ ))
	do
		echo "***************************************" >> ${LOGFILE}
		echo "Starting iteration ${itr}" >> ${LOGFILE}
		echo "***************************************" >> ${LOGFILE}
		if [ ${RE_DEPLOY} == "true" ]; then
			echo "Deploying the application..." >> ${LOGFILE}
			${SCRIPT_REPO}/tfb-qrh-deploy-openshift.sh -s ${BENCHMARK_SERVER} -n ${NAMESPACE} -i ${SCALING} -g ${TFB_IMAGE} --dbtype=${DB_TYPE} --dbhost=${DB_HOST} --cpureq=${CPU_REQ} --memreq=${MEM_REQ} --cpulim=${CPU_LIM} --memlim=${MEM_LIM} --usertunables=${OPTIONS_VAR} --quarkustpcorethreads=${quarkustpcorethreads} --quarkustpqueuesize=${quarkustpqueuesize} --quarkusdatasourcejdbcminsize=${quarkusdatasourcejdbcminsize} --quarkusdatasourcejdbcmaxsize=${quarkusdatasourcejdbcmaxsize} --FreqInlineSize=${FreqInlineSize} --MaxInlineLevel=${MaxInlineLevel} --MinInliningThreshold=${MinInliningThreshold} --CompileThreshold=${CompileThreshold} --CompileThresholdScaling=${CompileThresholdScaling} --ConcGCThreads=${ConcGCThreads} --InlineSmallCode=${InlineSmallCode} --LoopUnrollLimit=${LoopUnrollLimit} --LoopUnrollMin=${LoopUnrollMin} --MinSurvivorRatio=${MinSurvivorRatio} --NewRatio=${NewRatio} --TieredStopAtLevel=${TieredStopAtLevel} --TieredCompilation=${TieredCompilation} --AllowParallelDefineClass=${AllowParallelDefineClass} --AllowVectorizeOnDemand=${AllowVectorizeOnDemand} --AlwaysCompileLoopMethods=${AlwaysCompileLoopMethods} --AlwaysPreTouch=${AlwaysPreTouch} --AlwaysTenure=${AlwaysTenure} --BackgroundCompilation=${BackgroundCompilation} --DoEscapeAnalysis=${DoEscapeAnalysis} --UseInlineCaches=${UseInlineCaches} --UseLoopPredicate=${UseLoopPredicate} --UseStringDeduplication=${UseStringDeduplication} --UseSuperWord=${UseSuperWord} --UseTypeSpeculation=${UseTypeSpeculation} >> ${LOGFILE}
			# err_exit "Error: tfb-qrh deployment failed" >> ${LOGFILE}
		fi
		# Add extra sleep time for the deployment to complete as few machines takes longer time.
		sleep 180
		
		##Debug
		#Extra sleep time
		#sleep 600
		
		# Start the load
		RESULTS_DIR_I=${RESULTS_DIR_R}/ITR-${itr}
		echo "Running ${WARMUPS} warmups" >> ${LOGFILE}
		# Perform warmup runs
		runItr warmup ${WARMUPS} ${RESULTS_DIR_I}
		echo "Running ${MEASURES} measures" >> ${LOGFILE}
		# Perform measure runs
		runItr measure ${MEASURES} ${RESULTS_DIR_I}
		sleep 15
		# get the kruize recommendation for tfb application
		# commenting for now as it is not required in all cases
		#get_recommendations_from_kruize ${RESULTS_DIR_I}
		echo "***************************************" >> ${LOGFILE}
		echo "Completed iteration ${itr}..." >> ${LOGFILE}
		echo "***************************************" >> ${LOGFILE}
	done
}

echo "INSTANCES ,  THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m , MAX_RESPONSE_TIME , RESPONSE_TIME_50p , RESPONSE_TIME_95p , RESPONSE_TIME_97p , RESPONSE_TIME_99p , RESPONSE_TIME_99.9p , RESPONSE_TIME_99.99p , RESPONSE_TIME_99.999p , RESPONSE_TIME_100p , CPU_USAGE , MEM_USAGE , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , THRPT_PROM_CI , RSPTIME_PROM_CI" > ${RESULTS_DIR_ROOT}/Metrics-prom.log
echo ", THROUGHPUT_WRK , RESPONSETIME_WRK , RESPONSETIME_MAX_WRK , RESPONSETIME_STDEV_WRK , WEB_ERRORS , THRPT_WRK_CI , RSPTIME_WRK_CI" > ${RESULTS_DIR_ROOT}/Metrics-wrk.log
echo ", CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , QRKS_TP_CORETHREADS , QRKS_TP_QUEUESIZE , QRKS_DS_JDBC_MINSIZE , QRKS_DS_JDBC_MAXSIZE , FreqInlineSize , MaxInlineLevel , MinInliningThreshold , CompileThreshold , CompileThresholdScaling , ConcGCThreads , InlineSmallCode , LoopUnrollLimit , LoopUnrollMin  , MinSurvivorRatio , NewRatio , TieredStopAtLevel , TieredCompilation , AllowParallelDefineClass , AllowVectorizeOnDemand , AlwaysCompileLoopMethods , AlwaysPreTouch , AlwaysTenure , BackgroundCompilation , DoEscapeAnalysis , UseInlineCaches , UseLoopPredicate , UseStringDeduplication , UseSuperWord , UseTypeSpeculation" > ${RESULTS_DIR_ROOT}/Metrics-config.log

echo "INSTANCES , CLUSTER_CPU% , C_CPU_REQ% , C_CPU_LIM% , CLUSTER_MEM% , C_MEM_REQ% , C_MEM_LIM% " > ${RESULTS_DIR_ROOT}/Metrics-cluster.log
echo "RUN , CPU_REQ , MEM_REQ , CPU_LIM , MEM_LIM , THROUGHPUT , RESPONSETIME , WEB_ERRORS , RESPONSETIME_MAX , RESPONSETIME_STDEV , CPU , CPU_MIN , CPU_MAX , MEM , MEM_MIN , MEM_MAX" > ${RESULTS_DIR_ROOT}/Metrics-raw.log
echo "INSTANCES ,  MEM_RSS , MEM_USAGE " > ${RESULTS_DIR_ROOT}/Metrics-mem-prom.log
echo "INSTANCES ,  CPU_USAGE" > ${RESULTS_DIR_ROOT}/Metrics-cpu-prom.log
echo ", 50p , 95p , 98p , 99p , 99.9p" > ${RESULTS_DIR_ROOT}/Metrics-percentile-prom.log
echo "ITR , THROUGHPUT , RESPONSE_TIME , THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m" >> ${RESULTS_DIR_ROOT}/server_requests-metrics-measure-raw.log
echo "THROUGHPUT_RATE_1m , RESPONSE_TIME_RATE_1m , THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m , THROUGHPUT_RATE_5m , RESPONSE_TIME_RATE_5m , THROUGHPUT_RATE_6m , RESPONSE_TIME_RATE_6m " > ${RESULTS_DIR_ROOT}/Metrics-rate-prom.log
echo "INSTANCES , 50p_HISTO , 95p_HISTO , 97p_HISTO , 99p_HISTO , 99.9p_HISTO , 99.99p_HISTO , 99.999p_HISTO , 100p_HISTO" >> ${RESULTS_DIR_ROOT}/Metrics-quantiles-prom.log
echo "INSTANCES , CPU_MAXSPIKE , MEM_MAXSPIKE "  >> ${RESULTS_DIR_ROOT}/Metrics-spikes-prom.log
echo "50p_HISTO , 95p_HISTO , 97p_HISTO , 99p_HISTO , 99.9p_HISTO , 99.99p_HISTO , 99.999p_HISTO , 100p_HISTO" >> ${RESULTS_DIR_ROOT}/Metrics-histogram-prom.log

echo ", ${CPU_REQ} , ${MEM_REQ} , ${CPU_LIM} , ${MEM_LIM} , ${quarkustpcorethreads} , ${quarkustpqueuesize} , ${quarkusdatasourcejdbcminsize} , ${quarkusdatasourcejdbcmaxsize} , ${FreqInlineSize} , ${MaxInlineLevel} , ${MinInliningThreshold} , ${CompileThreshold} , ${CompileThresholdScaling} , ${ConcGCThreads} , ${InlineSmallCode} , ${LoopUnrollLimit} , ${LoopUnrollMin} , ${MinSurvivorRatio} , ${NewRatio} , ${TieredStopAtLevel} , ${TieredCompilation} , ${AllowParallelDefineClass} , ${AllowVectorizeOnDemand} , ${AlwaysCompileLoopMethods} , ${AlwaysPreTouch} , ${AlwaysTenure} , ${BackgroundCompilation} , ${DoEscapeAnalysis} , ${UseInlineCaches} , ${UseLoopPredicate} , ${UseStringDeduplication} , ${UseSuperWord} , ${UseTypeSpeculation} " >> ${RESULTS_DIR_ROOT}/Metrics-config.log

#TODO Create a function on how many DB inst required for a server. For now,defaulting it to 1
# Scale the instances and run the iterations
for (( scale=1; scale<=${TOTAL_INST}; scale++ ))
do
	RESULTS_SC=${RESULTS_DIR_ROOT}/scale_${scale}
	echo "Run in progress..."
	echo "***************************************" >> ${LOGFILE}
	echo "Run logs are placed at... " ${RESULTS_DIR_ROOT} >> ${LOGFILE}
	echo "***************************************" >> ${LOGFILE}
	echo "Running the benchmark with ${scale}  instances with ${TOTAL_ITR} iterations having ${WARMUPS} warmups and ${MEASURES} measurements" >> ${LOGFILE}
	# Perform warmup and measure runs
	runIterations ${scale} ${TOTAL_ITR} ${WARMUPS} ${MEASURES} ${RESULTS_SC}
	echo "Parsing results for ${scale} instances" >> ${LOGFILE}
	# Parse the results
	${SCRIPT_REPO}/perf/parsemetrics-wrk.sh ${TOTAL_ITR} ${RESULTS_SC} ${scale} ${WARMUPS} ${MEASURES} ${NAMESPACE} ${SCRIPT_REPO}
	sleep 5
	${SCRIPT_REPO}/perf/parsemetrics-promql.sh ${TOTAL_ITR} ${RESULTS_SC} ${scale} ${WARMUPS} ${MEASURES} ${SCRIPT_REPO}
	
done

## Cleanup all the deployments
${SCRIPT_REPO}/tfb-cleanup.sh -c openshift -n ${NAMESPACE} >> ${LOGFILE}
sleep 10
echo " "
# Display the Metrics log file
paste ${RESULTS_DIR_ROOT}/Metrics-prom.log ${RESULTS_DIR_ROOT}/Metrics-wrk.log ${RESULTS_DIR_ROOT}/Metrics-config.log
paste ${RESULTS_DIR_ROOT}/Metrics-quantiles-prom.log
