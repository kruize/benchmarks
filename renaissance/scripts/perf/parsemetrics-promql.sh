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
### Script to parse prometheus query data###


CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/../utils/common.sh

# Parse CPU, memory and cluster information
# input:type of run(warmup|measure), total number of runs, iteration number
# output:Creates cpu, memory and cluster information in the form of log files for each run
function parsePromMetrics()  {
	TYPE=$1
	TOTAL_RUNS=$2
	ITR=$3

	for (( run=0 ; run<"${TOTAL_RUNS}" ;run++))
	do
	  for poddatalog in "${POD_CPU_LOGS[@]}"
		do
			# Parsing CPU, app metric logs for pod
			parsePodDataLog ${poddatalog} ${TYPE} ${run} ${ITR}
		done
		for podmemlog in "${POD_MEM_LOGS[@]}"
		do
			# Parsing Mem logs for pod
			parsePodMemLog ${podmemlog} ${TYPE} ${run} ${ITR}
		done
		for poddiskdetailslog in "${POD_DISK_DETAILS_LOGS[@]}"
		do
			# Parsing Mem logs for pod
			parseDataLog ${poddiskdetailslog} ${TYPE} ${run} ${ITR}
		done
		for podnetworklog in "${POD_NW_LOGS[@]}"
		do
			# Parsing Network receive logs for pod
			parseDataLog ${podnetworklog} ${TYPE} ${run} ${ITR}
		done

		for podiolog in "${POD_IO_LOGS[@]}"
		do
			# Parsing Network transmit logs for pod
			parseDataLog ${podiolog} ${TYPE} ${run} ${ITR}
		done
	done
}
# Parsing CPU logs for pod
# input: podcpulogs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates cpu log for pod
function parsePodDataLog()
{
	MODE=$1
	TYPE=$2
	RUN=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	data_sum=0
	data_min=0
	data_max=0
	DATA_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${RUN}.json
	RUN_PODS=($(cat ${DATA_LOG} | cut -d ";" -f2 | sort | uniq))

	#TEMP_LOG=${RESULTS_DIR_P}/temp-data-${MODE}.log
	for run_pod in "${RUN_PODS[@]}"
	do
     if [ -s "${DATA_LOG}" ]; then
    cat ${DATA_LOG} | grep ${run_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${RESULTS_DIR_P}/temp-data.log
    each_pod_data_avg=$( echo `calcAvg ${RESULTS_DIR_P}/temp-data.log | cut -d "=" -f2`  )
    each_pod_data_min=$( echo `calcMin ${RESULTS_DIR_P}/temp-data.log` )
    each_pod_data_max=$( echo `calcMax ${RESULTS_DIR_P}/temp-data.log` )
    data_sum=$(echo ${data_sum}+${each_pod_data_avg}| bc -l)
    data_min=$(echo ${data_min}+${each_pod_data_min}| bc -l)
    data_max=$(echo ${data_max}+${each_pod_data_max} | bc -l)
    fi
	done
	echo "${run} , ${data_sum}, ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	echo ",${data_sum} , ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
}

# Parsing memory logs for pod
# input: podmemlogs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates memory log for pod
function parsePodMemLog()
{
	MODE=$1
	TYPE=$2
	RUN=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	mem_sum=0
	mem_min=0
	mem_max=0

	MEM_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${RUN}.json
	MEM_PODS=($(cat ${MEM_LOG} | cut -d ";" -f2 | sort | uniq))

	TEMP_LOG=${RESULTS_DIR_P}/temp-mem-${MODE}.log
	for mem_pod in "${MEM_PODS[@]}"
	do
		if [ -s "${MEM_LOG}" ]; then
                        cat ${MEM_LOG} | grep ${mem_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${RESULTS_DIR_P}/temp-data.log
                        each_pod_mem_avg=$( echo `calcAvg_inMB ${RESULTS_DIR_P}/temp-data.log | cut -d "=" -f2`  )
                        each_pod_mem_min=$( echo `calcMin ${RESULTS_DIR_P}/temp-data.log`  )
                        each_pod_mem_min_inMB=$(echo ${each_pod_mem_min}/1024/1024 | bc)
                        each_pod_mem_max=$( echo `calcMax ${RESULTS_DIR_P}/temp-data.log`  )
                        each_pod_mem_max_inMB=$(echo ${each_pod_mem_max}/1024/1024 | bc)
                        mem_sum=$(echo ${mem_sum}+${each_pod_mem_avg} | bc)
                        mem_min=$(echo ${mem_min}+${each_pod_mem_min_inMB} | bc)
                        mem_max=$(echo ${mem_max}+${each_pod_mem_max_inMB} | bc)
    fi
	done
	echo "${run} , ${mem_sum}, ${mem_min} , ${mem_max} " >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	echo ", ${mem_sum} , ${mem_min} , ${mem_max} " >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
}

# Parsing memory logs for pod
# input: clusterlogs array element, json file with cluster information, result log file
# output:creates clsuter log file
function parseDataLog()
{
	MODE=$1
	TYPE=$2
	RUN=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	data_sum=0
	data_min=0
	data_max=0
	DATA_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${RUN}.json
	RUN_PODS=($(cat ${DATA_LOG} | cut -d ";" -f2 | sort | uniq))
	for run_pod in "${RUN_PODS[@]}"
	do
		if [ -s "${DATA_LOG}" ]; then
                        cat ${DATA_LOG} | cut -d ";" -f2 | cut -d '"' -f1 > ${RESULTS_DIR_P}/temp-data.log
                        each_pod_data_avg=$( echo `calcAvg ${RESULTS_DIR_P}/temp-data.log | cut -d "=" -f2`  )
                        each_pod_data_min=$( echo `calcMin ${RESULTS_DIR_P}/temp-data.log` )
                        each_pod_data_max=$( echo `calcMax ${RESULTS_DIR_P}/temp-data.log` )
                        data_sum=$(echo ${data_sum}+${each_pod_data_avg}| bc -l)
                        data_min=$(echo ${data_min}+${each_pod_data_min}| bc -l)
                        data_max=$(echo ${data_max}+${each_pod_data_max} | bc -l)
    fi
	done
	echo "${run} , ${data_sum}, ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	echo ",${data_sum} , ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
}

#function parsePodNetworkLog()
#{
#	MODE=$1
#	TYPE=$2
#	RUN=$3
#	ITR=$4
#	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	#data_sum=0
	#data_min=0
	#data_max=0
	#DATA_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${RUN}.json
	#RUN_PODS=($(cat ${DATA_LOG} | cut -d ";" -f2 | sort | uniq))

	#TEMP_LOG=${RESULTS_DIR_P}/temp-data-${MODE}.log
	#for run_pod in "${RUN_PODS[@]}"
#	do
	#	if [ -s "${DATA_LOG}" ]; then
   #                     cat ${DATA_LOG} | grep ${run_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${TEMP_LOG}
    #                    each_pod_data_avg=$( echo `calcAvg ${TEMP_LOG} | cut -d "=" -f2`  )
    #                    each_pod_data_min=$( echo `calcMin ${TEMP_LOG}` )
     #                   each_pod_data_max=$( echo `calcMax ${TEMP_LOG}` )
     #                   data_sum=$(echo ${data_sum}+${each_pod_data_avg}| bc -l)
     #                   data_min=$(echo ${data_min}+${each_pod_data_min}| bc -l)
     #                   data_max=$(echo ${data_max}+${each_pod_data_max} | bc -l)
    #fi
	#done
	#echo "${run} , ${data_sum}, ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	#echo ",${data_sum} , ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
#}
#function parsePodIOLog()
#{
	#MODE=$1
#	TYPE=$2
#	RUN=$3
#	ITR=$4
#	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
#	data_sum=0
#	data_min=0
#	data_max=0
#	DATA_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${RUN}.json
#	RUN_PODS=($(cat ${DATA_LOG} | cut -d ";" -f2 | sort | uniq))

#	TEMP_LOG=${RESULTS_DIR_P}/temp-data-${MODE}.log
#	for run_pod in "${RUN_PODS[@]}"
#	do
#		if [ -s "${DATA_LOG}" ]; then
#                        cat ${DATA_LOG} | grep ${run_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${TEMP_LOG}
#                        each_pod_data_avg=$( echo `calcAvg ${TEMP_LOG} | cut -d "=" -f2`  )
 #                       each_pod_data_min=$( echo `calcMin ${TEMP_LOG}` )
 #                       each_pod_data_max=$( echo `calcMax ${TEMP_LOG}` )
 #                       data_sum=$(echo ${data_sum}+${each_pod_data_avg}| bc -l)
  #                      data_min=$(echo ${data_min}+${each_pod_data_min}| bc -l)
 #                       data_max=$(echo ${data_max}+${each_pod_data_max} | bc -l)
 #   fi
#	done
#	echo "${run} , ${data_sum}, ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${RESULTS_LOG}
#	echo ",${data_sum} , ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
# }




# Parse the results of jmeter load for each instance of application
# input: total number of iterations, result directory, Total number of instances
# output: Parse the results and generate the Metrics log files
function parseResults() {
	TOTAL_ITR=$1
	RESULTS_DIR_J=$2
	SCALE=$3
	WARMUPS=$4
	MEASURES=$5

	for (( itr=0 ; itr<${TOTAL_ITR} ;itr++))
	do
		RESULTS_DIR_P=${RESULTS_DIR_J}/ITR-${itr}
		parsePromMetrics warmup ${WARMUPS} ${itr}
		parsePromMetrics measure ${MEASURES} ${itr}

		for poddatalog in "${POD_CPU_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${poddatalog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${poddatalog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${poddatalog}_max-measure-temp.log
      fi
		done
		for podmemlog in "${POD_MEM_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podmemlog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podmemlog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podmemlog}_max-measure-temp.log
      fi
		done
		for poddiskdetailslog in "${POD_DISK_DETAILS_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${poddiskdetailslog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${poddiskdetailslog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${poddiskdetailslog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${poddiskdetailslog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${poddiskdetailslog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${poddiskdetailslog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${poddiskdetailslog}_max-measure-temp.log
      fi
		done
		for podnetworklog in "${POD_NW_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${podnetworklog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${podnetworklog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podnetworklog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podnetworklog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podnetworklog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podnetworklog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podnetworklog}_max-measure-temp.log
      fi
		done



    for podiolog in "${POD_IO_LOGS[@]}"
    do
            		   if [ -s "${RESULTS_DIR_J}/${podiolog}-measure-${itr}.log" ]; then
                                                                          cat ${RESULTS_DIR_J}/${podiolog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podiolog}-measure-temp.log
                                                                          cat ${RESULTS_DIR_J}/${podiolog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podiolog}_min-measure-temp.log
                                                                          cat ${RESULTS_DIR_J}/${podiolog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podiolog}_max-measure-temp.log
                   fi
    done
	#	for podfsreadtotallog in "${POD_FS_READ_TOTAL_LOGS[@]}"
   # do
   #  		   if [ -s "${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log" ]; then
    #                                                                                cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podtransmitlog}-measure-temp.log
   #                                                                                 cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podtransmitlog}_min-measure-temp.log
    #                                                                                cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podtransmitlog}_max-measure-temp.log
     #      fi
  #  done
 #   for podfswritetotallog in "${POD_FS_WRITE_TOTAL_LOGS[@]}"
  #  do
   #          		   if [ -s "${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log" ]; then
   #                                                                                         cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podtransmitlog}-measure-temp.log
    #                                                                                        cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podtransmitlog}_min-measure-temp.log
    #                                                                                        cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podtransmitlog}_max-measure-temp.log
    #               fi
    #done
    #for podrequestdurationcountlog in "${POD_REQUEST_DURATION_COUNT_LOGS[@]}"
    #do
    #             		   if [ -s "${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log" ]; then
     #                                                                                                             cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podtransmitlog}-measure-temp.log
      #                                                                                                            cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podtransmitlog}_min-measure-temp.log
       #                                                                                                           cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podtransmitlog}_max-measure-temp.log
       #                fi
    #done
   # for podrequestdurationsumlog in "${POD_REQUEST_DURATION_SUM_LOGS[@]}"
   # do
   #                      		   if [ -s "${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log" ]; then
   #                                                                                                                       cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podtransmitlog}-measure-temp.log
    #                                                                                                                      cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podtransmitlog}_min-measure-temp.log
     #                                                                                                                     cat ${RESULTS_DIR_J}/${podtransmitlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podtransmitlog}_max-measure-temp.log
     #                          fi
    #done
  done
	###### Add different raw logs we want to merge
	#Cumulative raw data
	paste ${RESULTS_DIR_J}/cpu-measure-raw.log ${RESULTS_DIR_J}/mem-measure-raw.log >> ${RESULTS_DIR_J}/../Metrics-cpumem-raw.log

	for metric in "${TOTAL_LOGS[@]}"
	do
		if [ -s ${RESULTS_DIR_J}/${metric}-measure-temp.log ]; then
		if [ ${metric} == "cpu_min" ] || [ ${metric} == "mem_min" ] || [ ${metric} == "memusage_min" ] || [ ${metric} == "diskdetails_min" ] || [ ${metric} == "netreceivebytes_min" ] || [ ${metric} == "nettransmitbytes_min" ] || [ ${metric} == "cnetreceivebytes_min" ] || [ ${metric} == "cnettransmitbytes_min" ] || [ ${metric} == "fsiototal_min" ] || [ ${metric} == "fsreadtotal_min" ] || [ ${metric} == "fswritetotal_min" ]  || [ ${metric} == "request_count_min" ] || [ ${metric} == "request_sum_min" ]; then
			 minval=$(echo `calcMin ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
		   if [ ! -z ${minval} ]; then
				eval total_${metric}=${minval}
		   else
				eval total_${metric}=0
		   fi
		elif [ ${metric} == "cpu_max" ] || [ ${metric} == "mem_max" ] || [ ${metric} == "memusage_max" ] || [ ${metric} == "diskdetails_max" ] || [ ${metric} == "netreceivebytes_max" ] || [ ${metric} == "nettransmitbytes_max" ] || [ ${metric} == "cnetreceivebytes_max" ] || [ ${metric} == "cnettransmitbytes_max" ] || [ ${metric} == "fsiototal_max" ] || [ ${metric} == "fsreadtotal_max" ] || [ ${metric} == "fswritetotal_max" ]  || [ ${metric} == "request_count_max" ] || [ ${metric} == "request_sum_max" ]; then
			maxval=$(echo `calcMax ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
		  if [ ! -z ${maxval} ]; then
				eval total_${metric}=${maxval}
		  else
				eval total_${metric}=0
		  fi
		else
			val=$(echo `calcAvg ${RESULTS_DIR_J}/${metric}-measure-temp.log | cut -d "=" -f2`)
			if [ ! -z ${val} ]; then
				eval total_${metric}_avg=${val}
			else
				eval total_${metric}_avg=0
		  fi
	  fi

		# Calculate confidence interval
		metric_ci=`php ${SCRIPT_REPO}/../utils/ci.php ${RESULTS_DIR_J}/${metric}-measure-temp.log`
		echo "metric_ci = $metric_ci"
		if [ ! -z ${metric_ci} ]; then
			eval ci_${metric}=${metric_ci}
		else
			eval ci_${metric}=0
		fi
   fi
  done

	echo "INSTANCES ,  CPU_USAGE , MEM_RSS_USAGE , MEM_USAGE , DISKDETAILS_USAGE , NETTRANSMITBYTES_USAGE , NETRECEIVEBYTES_USAGE , CNETTRANSMITBYTES_USAGE , CNETRECEIVEBYTES_USAGE , FSIOTOTAL_USAGE , FSREADTOTAL_USAGE , FSWRITETOTAL_USAGE , CPU_MIN , CPU_MAX , MEM_RSS_MIN , MEM_RSS_MAX , MEM_MIN , MEM_MAX , DISKDETAILS_MIN , DISKDETAILS_MAX , NETTRANSMITBYTES_MIN , NETTRANSMITBYTES_MAX , NETRECEIVEBYTES_MIN , NETRECEIVEBYTES_MAX , CNETTRANSMITBYTES_MIN , CNETTRANSMITBYTES_MAX , CNETRECEIVEBYTES_MIN , CNETRECEIVEBYTES_MAX , FSIOTOTAL_MIN , FSIOTOTAL_MAX , FSREADTOTAL_MIN , FSREADTOTAL_MAX , FSWRITETOTAL_MIN , FSWRITETOTAL_MAX" > ${RESULTS_DIR_J}/Metrics-prom.log

#	echo "${SCALE} , ${total_server_requests_thrpt_rate_3m_avg} , ${total_server_requests_rsp_time_rate_3m_avg} , ${total_server_requests_ms_max} , ${total_http_ms_quan_50_histo_avg} , ${total_http_ms_quan_95_histo_avg} , ${total_http_ms_quan_97_histo_avg} , ${total_http_ms_quan_99_histo_avg} , ${total_http_ms_quan_999_histo_avg} , ${total_http_ms_quan_9999_histo_avg} , ${total_http_ms_quan_99999_histo_avg} , ${total_http_ms_quan_100_histo_avg} , ${total_cpu_avg} , ${total_mem_avg} , ${total_cpu_min} , ${total_cpu_max} , ${total_mem_min} , ${total_mem_max} , ${ci_server_requests_thrpt_rate_3m} , ${ci_server_requests_rsp_time_rate_3m} " >> ${RESULTS_DIR_J}/../Metrics-prom.log

	echo "${SCALE} , ${total_cpu_avg} , ${total_mem_avg} , ${total_memusage_avg} , ${total_diskdetails_avg} , ${total_nettransmitbytes_avg} , ${total_netreceivebytes_avg}  , ${total_cnettransmitbytes_avg} , ${total_cnetreceivebytes_avg} , ${total_fsiototal_avg} , ${total_fsreadtotal_avg} , ${total_fswritetotal_avg} , ${total_cpu_min} , ${total_cpu_max} , ${total_mem_min} , ${total_mem_max} , ${total_memusage_min} , ${total_memusage_max} , ${total_diskdetails_min} , ${total_diskdetails_max} , ${total_nettransmitbytes_min} , ${total_nettransmitbytes_max} , ${total_netreceivebytes_min} , ${total_netreceivebytes_max} , ${total_cnettransmitbytes_min} , ${total_cnettransmitbytes_max} , ${total_cnetreceivebytes_min} , ${total_cnetreceivebytes_max} , ${total_fsiototal_min} , ${total_fsiototal_max} , ${total_fsreadtotal_min} , ${total_fsreadtotal_max} , ${total_fswritetotal_min} , ${total_fswritetotal_max}" >> ${RESULTS_DIR_J}/Metrics-prom.log

  echo "${SCALE} ,  ${total_mem_avg} , ${total_memusage_avg} " >> ${RESULTS_DIR_J}/Metrics-mem-prom.log
  echo "${SCALE} ,  ${total_cpu_avg} " >> ${RESULTS_DIR_J}/Metrics-cpu-prom.log
#       echo "${SCALE} , ${total_c_cpu_avg} , ${total_c_cpurequests_avg} , ${total_c_cpulimits_avg} , ${total_c_mem_avg} , ${total_c_memrequests_avg} , ${total_c_memlimits_avg} " >> ${RESULTS_DIR_J}/../Metrics-cluster.log
        #echo "${total_server_requests_thrpt_rate_1m_avg} , ${total_server_requests_rsp_time_rate_1m_avg} , ${total_server_requests_thrpt_rate_3m_avg} , ${total_server_requests_rsp_time_rate_3m_avg} , ${total_server_requests_thrpt_rate_5m_avg} , ${total_server_requests_rsp_time_rate_5m_avg} , ${total_server_requests_thrpt_rate_6m_avg} , ${total_server_requests_rsp_time_rate_6m_avg} " >> ${RESULTS_DIR_J}/Metrics-rate-prom.log
#        echo "${SCALE} , ${total_http_ms_quan_50_histo_avg} , ${total_http_ms_quan_95_histo_avg} , ${total_http_ms_quan_97_histo_avg} , ${total_http_ms_quan_99_histo_avg} , ${total_http_ms_quan_999_histo_avg} , ${total_http_ms_quan_9999_histo_avg} , ${total_http_ms_quan_99999_histo_avg} , ${total_http_ms_quan_100_histo_avg}" >> ${RESULTS_DIR_J}/Metrics-quantiles-prom.log
  echo "${SCALE} , ${total_maxspike_cpu_max} , ${total_maxspike_mem_max} "  >> ${RESULTS_DIR_J}/Metrics-spikes-prom.log

 #       paste ${RESULTS_DIR_J}/http_seconds_quan_50_histo-measure-temp.log ${RESULTS_DIR_J}/http_seconds_quan_95_histo-measure-temp.log ${RESULTS_DIR_J}/http_seconds_quan_97_histo-measure-temp.log ${RESULTS_DIR_J}/http_seconds_quan_99_histo-measure-temp.log ${RESULTS_DIR_J}/http_seconds_quan_999_histo-measure-temp.log ${RESULTS_DIR_J}/http_seconds_quan_9999_histo-measure-temp.log ${RESULTS_DIR_J}/http_seconds_quan_99999_histo-measure-temp.log ${RESULTS_DIR_J}/http_seconds_quan_100_histo-measure-temp.log >> ${RESULTS_DIR_J}/Metrics-histogram-prom.log
}

POD_CPU_LOGS=(cpu)
POD_MEM_LOGS=(mem memusage)
POD_DISK_DETAILS_LOGS=(diskdetails)
POD_NW_LOGS=(netreceivebytes nettransmitbytes cnetreceivebytes cnettransmitbytes)
POD_IO_LOGS=(fsiototal fsreadtotal fswritetotal)

#TIMER_RATE_LOGS=(app_timer_count_rate_1m app_timer_count_rate_3m app_timer_count_rate_5m app_timer_count_rate_7m app_timer_count_rate_9m app_timer_count_rate_15m app_timer_count_rate_30m app_timer_sum_rate_1m app_timer_sum_rate_3m app_timer_sum_rate_5m app_timer_sum_rate_7m app_timer_sum_rate_9m app_timer_sum_rate_15m app_timer_sum_rate_30m)
#SERVER_REQUESTS_RATE_LOGS=(server_requests_count_rate_1m server_requests_count_rate_3m server_requests_count_rate_5m server_requests_count_rate_6m server_requests_sum_rate_1m server_requests_sum_rate_3m server_requests_sum_rate_5m server_requests_sum_rate_6m)
#HTTP_P_LOGS=(http_seconds_quan_50_histo http_seconds_quan_95_histo http_seconds_quan_97_histo http_seconds_quan_98_histo http_seconds_quan_99_histo http_seconds_quan_999_histo http_seconds_quan_9999_histo http_seconds_quan_99999_histo http_seconds_quan_100_histo)
#MICROMETER_LOGS=(app_timer_sum app_timer_count ${TIMER_RATE_LOGS[@]} server_requests_sum server_requests_count server_requests_max ${SERVER_REQUESTS_RATE_LOGS[@]} ${LATENCY_P_LOGS[@]} latency_seconds_max ${HTTP_P_LOGS[@]})
#APP_CALC_METRIC_LOGS=(app_timer_rsp_time app_timer_thrpt app_timer_rsp_time_rate_3m app_timer_thrpt_rate_3m)
#SERVER_REQUESTS_METRIC_LOGS=(server_requests_rsp_time server_requests_thrpt server_requests_rsp_time_rate_3m server_requests_thrpt_rate_3m)
#METRIC_LOGS=(${APP_CALC_METRIC_LOGS[@]} ${SERVER_REQUESTS_METRIC_LOGS[@]})
TOTAL_LOGS=(${POD_CPU_LOGS[@]} ${POD_MEM_LOGS[@]} ${POD_DISK_DETAILS_LOGS[@]} ${POD_NW_LOGS[@]} ${POD_IO_LOGS[@]} cpu_min cpu_max mem_min mem_max memusage_min memusage_max diskdetails_min diskdetails_max netreceivebytes_min netreceivebytes_max nettransmitbytes_min nettransmitbytes_max cnettransmitbytes_min cnettransmitbytes_max cnetreceivebytes_min cnetreceivebytes_max)


TOTAL_ITR=$1
RESULTS_DIR_J=$2
SCALE=$3
WARMUPS=$4
MEASURES=$5
SCRIPT_REPO=$6

parseResults ${TOTAL_ITR} ${RESULTS_DIR_J} ${SCALE} ${WARMUPS} ${MEASURES} ${SCRIPT_REPO}
