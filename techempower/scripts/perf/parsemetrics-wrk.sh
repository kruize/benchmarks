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
### Script to parse hyperfoil/wrk2 data###

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/../utils/common.sh

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
		responsetime=0
		max_responsetime=0
		stddev_responsetime=0
		svc_apis=($(oc status --namespace=${NAMESPACE} | grep "tfb-qrh" | grep port | cut -d " " -f1 | cut -d "/" -f3))
		for svc_api  in "${svc_apis[@]}"
		do
			RESULT_LOG=${RESULTS_DIR_P}/wrk-${svc_api}-${TYPE}-${run}.log
			throughput=`cat ${RESULT_LOG} | grep "Requests" | cut -d ":" -f2 `
			responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f2 `
			max_responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f6 `
			stddev_responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f4 `
			isms_responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f3 `
			isms_max_responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f7 `
			isms_stddev_responsetime=`cat ${RESULT_LOG} | grep "Latency:" | cut -d ":" -f2 | tr -s " " | cut -d " " -f5 `
			if [ "${isms_responsetime}" == "s" ]; then
				responsetime=$(echo ${responsetime}*1000 | bc)
			elif [ "${isms_max_responsetime}" == "s" ]; then
				max_responsetime=$(echo ${max_responsetime}*1000 | bc)
			elif [ "${isms_stddev_responsetime}" == "s" ]; then
				stddev_responsetime=$(echo ${stddev_responsetime}*1000 | bc)
			fi
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

# Parse the results of wrk load for each instance of application
# input: total number of iterations, result directory, Total number of instances
# output: Parse the results and generate the Metrics log files
function parseResults() {
	TOTAL_ITR=$1
	RESULTS_DIR_J=$2
	SCALE=$3
	for (( itr=0 ; itr<${TOTAL_ITR} ;itr++))
	do
		RESULTS_DIR_P=${RESULTS_DIR_J}/ITR-${itr}
		parseData warmup ${WARMUPS} ${itr}
		parseData measure ${MEASURES} ${itr}
		#Calculte Average and Median of Throughput, Memory and CPU  scores
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/throughput-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/responsetime-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/weberror-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f5 >> ${RESULTS_DIR_J}/responsetime_max-measure-temp.log
		cat ${RESULTS_DIR_J}/Throughput-measure-${itr}.log | cut -d "," -f6 >> ${RESULTS_DIR_J}/stdev_resptime_max-measure-temp.log
		###### Add different raw logs we want to merge
		#Cumulative raw data
		paste ${RESULTS_DIR_J}/Throughput-measure-raw.log ${RESULTS_DIR_J}/cpu-measure-raw.log ${RESULTS_DIR_J}/mem-measure-raw.log >>  ${RESULTS_DIR_J}/../Metrics-raw.log
	done
	for metric in "${throughputlogs[@]}"
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
		metric_ci=`php ${SCRIPT_REPO}/perf/ci.php ${RESULTS_DIR_J}/${metric}-measure-temp.log`
		eval ci_${metric}=${metric_ci}
	done

	## Update the responsetime as not usable if web-errors are non-zero
	#echo "${SCALE} ,  ${total_throughput_avg} , ${total_responsetime_avg} , ${total_responsetime_max} , ${total_stdev_resptime_max} , ${total_mem_avg} , ${total_cpu_avg} , ${total_cpu_min} , ${total_cpu_max} , ${total_mem_min} , ${total_mem_max} , ${CPU_REQ} , ${MEM_REQ} , ${CPU_LIM} , ${MEM_LIM} , ${maxinlinelevel} , ${quarkustpcorethreads} , ${quarkustpqueuesize} , ${quarkusdatasourcejdbcminsize} , ${quarkusdatasourcejdbcmaxsize} , ${total_weberror_avg} , ${ci_throughput} , ${ci_responsetime} ,  ${ci_mem} , ${ci_cpu} " >> ${RESULTS_DIR_J}/../Metrics.log
	echo ", ${total_throughput_avg} , ${total_responsetime_avg} , ${total_responsetime_max} , ${total_stdev_resptime_max} , ${total_weberror_avg} , ${ci_throughput} , ${ci_responsetime}" >> ${RESULTS_DIR_J}/../Metrics-wrk.log
	#echo "${SCALE} , ${ci_throughput} , ${ci_responsetime} ,  ${ci_mem} , ${ci_cpu} , ${ci_weberror} " >> ${RESULTS_DIR_J}/../Metrics-ci.log
}

throughputlogs=(throughput responsetime weberror responsetime_max stdev_resptime_max)
podcpulogs=(cpu)
podmemlogs=(mem memusage)
clusterlogs=(c_mem c_cpu)
total_logs=(${throughputlogs[@]} ${podcpulogs[@]} ${podmemlogs[@]} cpu_min cpu_max mem_min mem_max)

TOTAL_ITR=$1
RESULTS_SC=$2
SCALE=$3
WARMUPS=$4
MEASURES=$5
SCRIPT_REPO=$6

parseResults ${TOTAL_ITR} ${RESULTS_SC} ${SCALE} ${WARMUPS} ${MEASURES} ${SCRIPT_REPO}
