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
source ${CURRENT_DIR}/tfb-common.sh

# Run the benchmark as
# SCRIPT BENCHMARK_SERVER 
# Ex of ARGS :  -s example.in.com -i 2 -g kruize/tfb-qrh:1.13.2.F_mm.v1

CLUSTER_TYPE="openshift"

# Describes the usage of the script
function usage() {
	echo
	echo "Usage: $0 -s BENCHMARK_SERVER [-i SERVER_INSTANCES] [-n NAMESPACE] [-g TFB_IMAGE] [--cpureq=CPU_REQ] [--memreq=MEM_REQ] [--cpulim=CPU_LIM] [--memlim=MEM_LIM] "
	echo " "
	echo "Example: $0 -s example.in.com -i 2 -g kruize/tfb-qrh:1.13.2.F_mm.v1 --cpulim=4 --cpureq=2 --memlim=1024Mi --memreq=512Mi"
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
		TFB_IMAGE="${OPTARG}"		
		;;
	n)
		NAMESPACE="${OPTARG}"		
		;;
	esac
done

if [ -z "${BENCHMARK_SERVER}" ]; then
	echo "Do set the variable - BENCHMARK_SERVER "
	usage
	exit 1
fi

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${TFB_IMAGE}" ]; then
	TFB_IMAGE="${TFB_DEFAULT_IMAGE}"
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="${DEFAULT_NAMESPACE}"
fi

# check memory limit for unit
if [ ! -z "${MEM_LIM}" ]; then
	check_memory_unit ${MEM_LIM}
fi

# check memory request for unit
if [ ! -z "${MEM_REQ}" ]; then
	check_memory_unit ${MEM_REQ}
fi

# Create multiple yamls based on instances and Update the template yamls with names and create multiple files
# input:quarkus-resteasy-hibernate , postgres and service-monitor yaml file
function createInstances() {
	#Create the deployments and services

	# Deploy one instance of DB
	oc create -f ${MANIFESTS_DIR}/postgres.yaml -n ${NAMESPACE}
	sleep 10

	for(( inst=0; inst<"${SERVER_INSTANCES}"; inst++ ))
	do
		sed 's/name: tfb-qrh/name: tfb-qrh-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor.yaml > ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/tfb-qrh-app/tfb-qrh-app-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		sed -i 's/tfb-qrh-port/tfb-qrh-port-'${inst}'/g' ${MANIFESTS_DIR}/service-monitor-${inst}.yaml
		oc create -f ${MANIFESTS_DIR}/service-monitor-${inst}.yaml -n ${NAMESPACE}
	done
	for(( inst=0; inst<"${SERVER_INSTANCES}"; inst++ ))
	do
		sed 's/tfb-qrh-sample/tfb-qrh-sample-'${inst}'/g' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate.yaml > ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		sed -i "s|${TFB_DEFAULT_IMAGE}|${TFB_IMAGE}|g" ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		sed -i 's/tfb-qrh-service/tfb-qrh-service-'${inst}'/g' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		sed -i 's/tfb-qrh-app/tfb-qrh-app-'${inst}'/g' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		sed -i 's/tfb-qrh-port/tfb-qrh-port-'${inst}'/g' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
	
		# Setting cpu/mem request limits
		if [ ! -z  ${MEM_REQ} ]; then
			sed -i '/requests:/a \ \ \ \ \ \ \ \ \ \ memory: '${MEM_REQ}'' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		fi
		if [ ! -z  ${CPU_REQ} ]; then
			sed -i '/requests:/a \ \ \ \ \ \ \ \ \ \ cpu: '${CPU_REQ}'' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		fi
		if [ ! -z  ${MEM_LIM} ]; then
			sed -i '/limits:/a \ \ \ \ \ \ \ \ \ \ memory: '${MEM_LIM}'' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		fi
		if [ ! -z  ${CPU_LIM} ]; then
			sed -i '/limits:/a \ \ \ \ \ \ \ \ \ \ cpu: '${CPU_LIM}'' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
		fi

		tunables_jvm_boolean=(TieredCompilation AllowParallelDefineClass AllowVectorizeOnDemand AlwaysCompileLoopMethods AlwaysPreTouch AlwaysTenure BackgroundCompilation DoEscapeAnalysis UseInlineCaches UseLoopPredicate UseStringDeduplication UseSuperWord UseTypeSpeculation)
		tunables_jvm_values=(FreqInlineSize MaxInlineLevel MinInliningThreshold CompileThreshold CompileThresholdScaling ConcGCThreads InlineSmallCode LoopUnrollLimit LoopUnrollMin MinSurvivorRatio NewRatio TieredStopAtLevel)
		tunables_quarkus=(quarkustpcorethreads quarkustpqueuesize quarkusdatasourcejdbcminsize quarkusdatasourcejdbcmaxsize)

		user_options=$(echo ${OPTIONS_VAR} | tr ";" "\n")

		OPTIONS_VAR=""
		for useroption in ${user_options}
		do
			OPTIONS_VAR="${OPTIONS_VAR} ${useroption}"
		done

		for btunable in "${tunables_jvm_boolean[@]}"
                do
                        if [ ! -z ${!btunable} ]; then
                                if [ ${!btunable} == "true" ]; then
                                        OPTIONS_VAR="${OPTIONS_VAR} -XX:+${btunable}"
                                else
                                        OPTIONS_VAR="${OPTIONS_VAR} -XX:-${btunable}"
                                fi
                        fi
                done

		for jvtunable in "${tunables_jvm_values[@]}"
                do
                        if [ ! -z ${!jvtunable} ]; then
				OPTIONS_VAR="${OPTIONS_VAR} -XX:${jvtunable}=${!jvtunable}"
                        fi
                done
		
		for qtunable in "${tunables_quarkus[@]}"
                do
                        if [ ! -z ${!qtunable} ]; then
				if [ ${qtunable} == "quarkustpcorethreads" ]; then
	                                OPTIONS_VAR="${OPTIONS_VAR} -Dquarkus.thread-pool.core-threads=${!qtunable}"
				elif [ ${qtunable} == "quarkustpqueuesize" ]; then
                                        OPTIONS_VAR="${OPTIONS_VAR} -Dquarkus.thread-pool.queue-size=${!qtunable}"
				elif [ ${qtunable} == "quarkusdatasourcejdbcminsize" ]; then
                                        OPTIONS_VAR="${OPTIONS_VAR} -Dquarkus.datasource.jdbc.min-size=${!qtunable}"
				elif [ ${qtunable} == "quarkusdatasourcejdbcmaxsize" ]; then
                                        OPTIONS_VAR="${OPTIONS_VAR} -Dquarkus.datasource.jdbc.max-size=${!qtunable}"
				fi
                        fi

                done

                sed -i "/env:/a \ \ \ \ \ \ \ \ \ \ \ \ value: \"${OPTIONS_VAR}\" " ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml
                sed -i '/env:/a \ \ \ \ \ \ \ \ \ \ - name: "JAVA_OPTIONS"' ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml

		oc create -f ${MANIFESTS_DIR}/quarkus-resteasy-hibernate-${inst}.yaml -n ${NAMESPACE}
		#err_exit "Error: Issue in deploying tfb-qrh." >> ${LOGFILE}

		((TFB_PORT=TFB_PORT+1))

	done

	#Wait till tfb-qrh starts
	sleep 20

	#Expose the services
	SVC_LIST=($(oc get svc --namespace=${NAMESPACE} | grep "service" | grep "tfb-qrh" | cut -d " " -f1))
	for sv in "${SVC_LIST[@]}"
	do
		oc expose svc/${sv} --namespace=${NAMESPACE}
		#err_exit " Error: Issue in exposing service" >> ${LOGFILE}
	done

	## extra sleep time
	sleep 60
			
	# Check if the application is running
	#check_app >> ${LOGFILE}
}

# Delete the tfb-qrh and tfb-database deployments,services and routes if it is already present 
function stopAllInstances() {
	${TFB_REPO}/tfb-cleanup.sh -c ${CLUSTER_TYPE} -n ${NAMESPACE} >> ${LOGFILE}
	sleep 30

	##extra sleep time
#	sleep 60
}

# Stop all tfb related instances if there are any
stopAllInstances
# Deploying instances
createInstances ${SERVER_INSTANCES}
