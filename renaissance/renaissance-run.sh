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
### Script to perform load test on multiple instances of techempower Quarkus benchmarks on openshift###
#
CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/../tfb-common.sh
pushd "${CURRENT_DIR}" > /dev/null
pushd ".." > /dev/null
SCRIPT_REPO=${PWD}
pushd ".." > /dev/null
LOGFILE="${PWD}/setup.log"
K_CPU=2
K_MEM=6144
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
		oc logs pod/`oc get pods | grep "${APP_NAME}" | cut -d " " -f1` -n ${NAMESPACE} >> ${LOGFILE}
		echo "1 , 99999 , 99999 , 99999 , 99999 , 99999 , 999999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999 , 99999" >> ${RESULTS_DIR_ROOT}/Metrics-prom.log
		echo ", 99999 , 99999 , 99999 , 99999 , 9999 , 0 , 0" >> ${RESULTS_DIR_ROOT}/Metrics-wrk.log
		paste ${RESULTS_DIR_ROOT}/Metrics-prom.log ${RESULTS_DIR_ROOT}/Metrics-wrk.log ${RESULTS_DIR_ROOT}/Metrics-config.log ${RESULTS_DIR_ROOT}/deploy-config.log
		cat ${RESULTS_DIR_ROOT}/app-calc-metrics-measure-raw.log
		cat ${RESULTS_DIR_ROOT}/server_requests-metrics-${TYPE}-raw.log
		## Cleanup all the deployments
		${SCRIPT_REPO}/tfb-cleanup.sh -c ${CLUSTER_TYPE} -n ${NAMESPACE} >> ${LOGFILE}
		exit -1
	fi
}
# Run the benchmark as
# SCRIPT BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH WARMUPS MEASURES TOTAL_INST TOTAL_ITR RE_DEPLOY
# Ex of ARGS : --clustertype=openshift -s example.in.com -e /tfb/results -w 5 -m 3 -i 1 --iter=1 -r
# Describes the usage of the script
function usage() {
	echo
	echo "Usage: $0 --clustertype=CLUSTER_TYPE -s BENCHMARK_SERVER -e RESULTS_DIR_PATH [-w WARMUPS] [-m MEASURES] [-i TOTAL_INST] [--iter=TOTAL_ITR] [-r= set redeploy to true] [-n NAMESPACE] [-g TFB_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] [-t THREAD] [-R REQUEST_RATE] [-d DURATION] [--connection=CONNECTIONS]"
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
			clustertype=*)
				CLUSTER_TYPE=${OPTARG#*=}
				;;
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
			envoptions=*)
				ENV_OPTIONS=${OPTARG#*=}
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
if [[ -z "${CLUSTER_TYPE}" || -z "${BENCHMARK_SERVER}" || -z "${RESULTS_DIR_PATH}" ]]; then
	echo "Do set the variables - CLUSTER_TYPE, BENCHMARK_SERVER and RESULTS_DIR_PATH "
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
	CONNECTIONS="512"
fi

if [[ ${CLUSTER_TYPE} == "openshift" ]]; then
        K_EXEC="oc"
elif [[ ${CLUSTER_TYPE} == "minikube" ]]; then
        K_EXEC="kubectl"
fi

RESULTS_DIR_ROOT=${RESULTS_DIR_PATH}/tfb-$(date +%Y%m%d%H%M)
mkdir -p ${RESULTS_DIR_ROOT}

#Adding 5 secs buffer to retrieve CPU and MEM info
CPU_MEM_DURATION=`expr ${DURATION} + 5`
