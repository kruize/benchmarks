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
### Script to deploy the one or more instances of tfb application on openshift###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/renaissance-common.sh

SERVER_INSTANCES=1
DB_TYPE=${DEFAULT_DB_TYPE}
BENCHMARK_IMAGE="${prakalp23/renaissance1041:latest}"
NAMESPACE="${DEFAULT_NAMESPACE}"

# Run the benchmark as
# SCRIPT BENCHMARK_SERVER
# Ex of ARGS :  --clustertype=openshift -s example.in.com -i 2 -g kruize/tfb-qrh:1.13.2.F_mm.v1

# Describes the usage of the script
function usage() {
	echo
	echo "Usage: $0 --clustertype=CLUSTER_TYPE [-s BENCHMARK_SERVER] [-i SERVER_INSTANCES] [-n NAMESPACE] [-g TFB_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] "
	echo " "
	echo "Example: $0 --clustertype=openshift -s example.in.com -i 2 -g kruize/tfb-qrh:1.13.2.F_mm.v1 --cpulim=4 --cpureq=2 --memlim=1024Mi --memreq=512Mi"
	exit -1
}

# Check if the memory request/limit has unit. If not ask user to append the unit
# input: Memory request/limit passed by user
# output: Check memory request/limit for unit , if not specified suggest the user to specify the unit
function check_memory_unit() {
	MEM=$1
	case "${MEM}" in
		[0-9]*M)
			;;
		[0-9]*Mi)
			;;
		[0-9]*K)
			;;
		[0-9]*Ki)
			;;
		[0-9]*G)
			;;
		[0-9]*Gi)
			;;
		*)
			echo "Error : Do specify the memory Unit"
			echo "Example: ${MEM}K/Ki/M/Mi/G/Gi"
			usage
			;;
	esac
}

# Iterate through the commandline options
while getopts s:i:g:n:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			clustertype=*)
				CLUSTER_TYPE=${OPTARG#*=}
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
				JDK_JAVA_OPTIONS=${OPTARG#*=}
				;;
			usertunables=*)
				OPTIONS_VAR=${OPTARG#*=}
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
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	g)
		Benchmark_IMAGE="${OPTARG}"		
		;;
	n)
		NAMESPACE="${OPTARG}"		
		;;
	esac
done

if [ -z "${CLUSTER_TYPE}" ]; then
	echo "Do set the variable - CLUSTER_TYPE "
	usage
	exit 1
fi

# check memory limit for unit
if [ ! -z "${MEM_LIM}" ]; then
	check_memory_unit ${MEM_LIM}
fi

# check memory request for unit
if [ ! -z "${MEM_REQ}" ]; then
	check_memory_unit ${MEM_REQ}
fi

if [[ ${CLUSTER_TYPE} == "openshift" ]]; then
	K_EXEC="oc"
elif [[ ${CLUSTER_TYPE} == "minikube" ]]; then
	K_EXEC="kubectl"
fi


# Delete the renaissance and renaissance-database deployments,services and routes if it is already present 
function stopAllInstances() {
	${renaissance_REPO}/renaissance-cleanup.sh -c ${CLUSTER_TYPE} -n ${NAMESPACE} >> ${LOGFILE}
	sleep 30

	##extra sleep time
#	sleep 60
}

# Stop all renaissance related instances if there are any
stopAllInstances
# Deploying instances
createInstances ${SERVER_INSTANCES}
