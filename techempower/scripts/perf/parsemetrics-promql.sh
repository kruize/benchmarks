#!/bin/bash

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/../utils.sh

# Parse CPU, memeory and cluster information
# input:type of run(warmup|measure), total number of runs, iteration number
# output:Creates cpu, memory and cluster information in the form of log files for each run
function parsePromMetrics()  {
	TYPE=$1
	TOTAL_RUNS=$2
	ITR=$3

	echo "${TYPE} Runs" >> ${RESULTS_DIR_J}/Mem-${itr}.log
	for (( run=0 ; run<${TOTAL_RUNS} ;run++))
	do
		for poddatalog in "${podcpulogs[@]}"
		do
			# Parsing CPU, app metric logs for pod
			parsePodDataLog ${poddatalog} ${TYPE} ${run} ${ITR}
		done
		for podmemlog in "${podmemlogs[@]}"
		do
			# Parsing Mem logs for pod
			parsePodMemLog ${podmemlog} ${TYPE} ${run} ${ITR}
		done
#		for clusterlog in "${clusterlogs[@]}"
#		do
			# Parsing Cluster logs 
#			parseClusterLog ${clusterlog} ${RESULTS_DIR_P}/${clusterlog}-${TYPE}-${run}.json ${clusterlog}-${TYPE}-${itr}.log
#		done
	done

	for podmmlog in "${micrometer_logs[@]}"
	do
		parsePodMicroMeterLog ${podmmlog} ${TYPE} ${ITR}
	done

	## Calculate response time
	total_seconds_sum=`cat ${RESULTS_DIR_J}/app_timer_sum-${TYPE}-${ITR}.log`
	# Convert seconds to ms to avoid 0 as response time.
	total_milliseconds_sum=$(echo ${total_seconds_sum}*1000 | bc)
	total_seconds_count=`cat ${RESULTS_DIR_J}/app_timer_count-${TYPE}-${ITR}.log`
	rsp_time=$(echo ${total_milliseconds_sum}/${total_seconds_count}| bc)
	throughput=$(echo ${total_seconds_count}/${total_seconds_sum}| bc)
	echo ${rsp_time} > ${RESULTS_DIR_J}/app_timer_rsp_time-${TYPE}-${ITR}.log
	echo ${throughput} > ${RESULTS_DIR_J}/app_timer_thrpt-${TYPE}-${ITR}.log

	## Calculate rsp_time_rate and thrpt_rate
	app_sum_rate_3m=`cat ${RESULTS_DIR_J}/app_timer_sum_rate_3m-${TYPE}-${ITR}.log`
	# Convert seconds to ms to avoid 0 as response time.
        app_sum_rate_3m_inms=$(echo ${app_sum_rate_3m}*1000 | bc)
        app_count_rate_3m=`cat ${RESULTS_DIR_J}/app_timer_count_rate_3m-${TYPE}-${ITR}.log`
        rsp_time_rate_3m=$(echo ${app_sum_rate_3m_inms}/${app_count_rate_3m}| bc)
        throughput_rate_3m=$(echo ${app_count_rate_3m}/${app_sum_rate_3m}| bc)
        echo ${rsp_time_rate_3m} > ${RESULTS_DIR_J}/app_timer_rsp_time_rate_3m-${TYPE}-${ITR}.log
        echo ${throughput_rate_3m} > ${RESULTS_DIR_J}/app_timer_thrpt_rate_3m-${TYPE}-${ITR}.log

	## Raw data
	echo "${ITR}, ${throughput} , ${rsp_time} , ${throughput_rate_3m} , ${rsp_time_rate_3m} " >> ${RESULTS_DIR_J}/../app-calc-metrics-${TYPE}-raw.log
}

# Parsing micrometer metrics logs for pod
# input: app_timer logs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates cpu log for pod
function parsePodMicroMeterLog()
{
        MODE=$1
        TYPE=$2
        ITR=$3
        RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
        data_sum=0
        data_min=0
        data_max=0
                if [ ${MODE} == "app_timer_count" ] || [ ${MODE} == "app_timer_sum" ] ; then
			cat ${RESULTS_DIR_P}/${MODE}-${TYPE}*.json | cut -d ";" -f4 | cut -d '"' -f1 | uniq | grep -v "^$" | sort -n  > ${RESULTS_DIR_P}/temp-data.log
			start_counter=`cat ${RESULTS_DIR_P}/temp-data.log | head -1`
			end_counter=`cat ${RESULTS_DIR_P}/temp-data.log | tail -1`
			counter_val=$(echo ${end_counter}-${start_counter}| bc)
			echo "${counter_val}" > ${RESULTS_DIR_J}/${MODE}-${TYPE}-${ITR}.log
		elif [[ ${MODE} == *"app_timer_count_rate"* ]] || [[ ${MODE} == *"app_timer_sum_rate"* ]] ; then
			last_measure_number=$(echo ${MEASURES}-1 | bc)
			cat ${RESULTS_DIR_P}/${MODE}-${TYPE}-${last_measure_number}.json | cut -d ";" -f4 | cut -d "\"" -f1 | tail -1 > ${RESULTS_DIR_J}/${MODE}-${TYPE}-${ITR}.log
		elif [ ${MODE} == "latency_seconds_max" ] ; then
			cat ${RESULTS_DIR_P}/${MODE}-* | cut -d ";" -f4 | cut -d "\"" -f1 | uniq | grep -v "^$" | sort -n | tail -1 > ${RESULTS_DIR_J}/${MODE}-${TYPE}-${ITR}.log
		elif [[ ${MODE} == *"latency_seconds_quan"* ]] ; then
			last_measure_number=$(echo ${MEASURES}-1 | bc)
			cat ${RESULTS_DIR_P}/${MODE}-${TYPE}-${last_measure_number}.json | cut -d ";" -f4 | cut -d "\"" -f1 | uniq | grep -v "^$" | sort -n |  tail -1 > ${RESULTS_DIR_J}/${MODE}-${TYPE}-${ITR}.log
		fi

}

# Parsing CPU logs for pod
# input: podcpulogs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates cpu log for pod
function parsePodDataLog()
{
	MODE=$1
	TYPE=$2
	run=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	data_sum=0
	data_min=0
	data_max=0

	DATA_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${run}.json
	run_pods=($(cat ${DATA_LOG} | cut -d ";" -f2 | sort | uniq))
	for run_pod in "${run_pods[@]}"
	do
		cat ${DATA_LOG} | grep ${run_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${RESULTS_DIR_P}/temp-data.log
		each_pod_data_avg=$( echo `calcAvg ${RESULTS_DIR_P}/temp-data.log | cut -d "=" -f2`  )
		each_pod_data_min=$( echo `calcMin ${RESULTS_DIR_P}/temp-data.log` )
		each_pod_data_max=$( echo `calcMax ${RESULTS_DIR_P}/temp-data.log` )
		data_sum=$(echo ${data_sum}+${each_pod_data_avg}| bc)
		data_min=$(echo ${data_min}+${each_pod_data_min}| bc)
		data_max=$(echo ${data_max}+${each_pod_data_max} | bc)
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
	run=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	mem_sum=0
	mem_min=0
	mem_max=0

	MEM_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${run}.json
	mem_pods=($(cat ${MEM_LOG} | cut -d ";" -f2 | sort | uniq))
	for mem_pod in "${mem_pods[@]}"
	do
		cat ${MEM_LOG} | grep ${mem_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${RESULTS_DIR_P}/temp-mem.log
		each_pod_mem_avg=$( echo `calcAvg_inMB ${RESULTS_DIR_P}/temp-mem.log | cut -d "=" -f2`  )
		each_pod_mem_min=$( echo `calcMin ${RESULTS_DIR_P}/temp-mem.log`  )
		each_pod_mem_min_inMB=$(echo ${each_pod_mem_min}/1024/1024 | bc)
		each_pod_mem_max=$( echo `calcMax ${RESULTS_DIR_P}/temp-mem.log`  )
		each_pod_mem_max_inMB=$(echo ${each_pod_mem_max}/1024/1024 | bc)
		mem_sum=$(echo ${mem_sum}+${each_pod_mem_avg} | bc)
		mem_min=$(echo ${mem_min}+${each_pod_mem_min_inMB} | bc)
		mem_max=$(echo ${mem_max}+${each_pod_mem_max_inMB} | bc)
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

# Parse the results of jmeter load for each instance of application
# input: total number of iterations, result directory, Total number of instances
# output: Parse the results and generate the Metrics log files
function parseResults() {
	TOTAL_ITR=$1
	RESULTS_DIR_J=$2
	sca=$3
	WARMUPS=$4
	MEASURES=$5
	for (( itr=0 ; itr<${TOTAL_ITR} ;itr++))
	do
		RESULTS_DIR_P=${RESULTS_DIR_J}/ITR-${itr}
		parsePromMetrics warmup ${WARMUPS} ${itr}
		parsePromMetrics measure ${MEASURES} ${itr}

		for poddatalog in "${podcpulogs[@]}"
		do
			cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${poddatalog}-measure-temp.log
			cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${poddatalog}_min-measure-temp.log
			cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${poddatalog}_max-measure-temp.log
		done
		for podmemlog in "${podmemlogs[@]}"
		do
			cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podmemlog}-measure-temp.log
			cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podmemlog}_min-measure-temp.log
			cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podmemlog}_max-measure-temp.log
		done
#		for clusterlog in "${clusterlogs[@]}"
#		do
#			cat ${RESULTS_DIR_J}/${clusterlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${clusterlog}-measure-temp.log
#		done
		
		for podmmlog in "${micrometer_logs[@]}"
                do
                       cat ${RESULTS_DIR_J}/${podmmlog}-measure-${itr}.log >> ${RESULTS_DIR_J}/${podmmlog}-measure-temp.log
                done

		for podmetriclog in "${app_calc_metric_logs[@]}"
		do
                       cat ${RESULTS_DIR_J}/${podmetriclog}-measure-${itr}.log >> ${RESULTS_DIR_J}/${podmetriclog}-measure-temp.log
                done

		###### Add different raw logs we want to merge
		#Cumulative raw data
		paste ${RESULTS_DIR_J}/cpu-measure-raw.log ${RESULTS_DIR_J}/mem-measure-raw.log >> ${RESULTS_DIR_J}/../Metrics-cpumem-raw.log
	done

	for metric in "${total_logs[@]}"
	do
		if [ ${metric} == "cpu_min" ] || [ ${metric} == "mem_min" ]; then
			minval=$(echo `calcMin ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
			eval total_${metric}=${minval}
		elif [ ${metric} == "cpu_max" ] || [ ${metric} == "mem_max" ] || [ ${metric} == "latency_seconds_max" ]; then
			maxval=$(echo `calcMax ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
			eval total_${metric}=${maxval}
		else
			val=$(echo `calcAvg ${RESULTS_DIR_J}/${metric}-measure-temp.log | cut -d "=" -f2`)
			eval total_${metric}_avg=${val}
		fi
	
		# Calculate confidence interval
		metric_ci=`php ${SCRIPT_REPO}/perf/ci.php ${RESULTS_DIR_J}/${metric}-measure-temp.log`
                eval ci_${metric}=${metric_ci}	
	done

	## Convert latency_seconds_max into ms
	total_latency_milliseconds_max=$(echo ${total_latency_seconds_max}*1000 | bc)
	total_latency_ms_quan_50_avg=$(echo ${total_latency_seconds_quan_50_avg}*1000 | bc)
	total_latency_ms_quan_95_avg=$(echo ${total_latency_seconds_quan_95_avg}*1000 | bc)
	total_latency_ms_quan_98_avg=$(echo ${total_latency_seconds_quan_98_avg}*1000 | bc)
	total_latency_ms_quan_99_avg=$(echo ${total_latency_seconds_quan_99_avg}*1000 | bc)
	total_latency_ms_quan_999_avg=$(echo ${total_latency_seconds_quan_999_avg}*1000 | bc)
	echo "${sca} ,  ${total_app_timer_thrpt_avg} , ${total_app_timer_rsp_time_avg} , ${total_app_timer_thrpt_rate_3m_avg} , ${total_app_timer_rsp_time_rate_3m_avg} , ${total_latency_milliseconds_max} , ${total_latency_ms_quan_50_avg} , ${total_latency_ms_quan_95_avg} , ${total_latency_ms_quan_98_avg} , ${total_latency_ms_quan_99_avg} , ${total_latency_ms_quan_999_avg} , ${total_mem_avg} , ${total_cpu_avg} , ${total_cpu_min} , ${total_cpu_max} , ${total_mem_min} , ${total_mem_max} , ${ci_app_timer_thrpt} , ${ci_app_timer_rsp_time} " >> ${RESULTS_DIR_J}/../Metrics-prom.log
	echo "${sca} ,  ${total_mem_avg} , ${total_memusage_avg} " >> ${RESULTS_DIR_J}/../Metrics-mem-prom.log
	echo "${sca} ,  ${total_cpu_avg} " >> ${RESULTS_DIR_J}/../Metrics-cpu-prom.log
	echo ", ${total_latency_seconds_quan_50_avg} , ${total_latency_seconds_quan_95_avg} , ${total_latency_seconds_quan_98_avg} , ${total_latency_seconds_quan_99_avg} , ${total_latency_seconds_quan_999_avg}" >> ${RESULTS_DIR_J}/../Metrics-percentile-prom.log
#	echo "${sca} , ${total_c_cpu_avg} , ${total_c_cpurequests_avg} , ${total_c_cpulimits_avg} , ${total_c_mem_avg} , ${total_c_memrequests_avg} , ${total_c_memlimits_avg} " >> ${RESULTS_DIR_J}/../Metrics-cluster.log
#	echo "${sca} , ${total_app_timer_secondspercount_avg} ,  " >> ${RESULTS_DIR_J}/../Metrics-app.log

}

podcpulogs=(cpu)
podmemlogs=(mem memusage)
clusterlogs=(c_mem c_cpu)
timer_rate_logs=(app_timer_count_rate_1m app_timer_count_rate_3m app_timer_count_rate_5m app_timer_count_rate_7m app_timer_count_rate_9m app_timer_count_rate_15m app_timer_count_rate_30m app_timer_sum_rate_1m app_timer_sum_rate_3m app_timer_sum_rate_5m app_timer_sum_rate_7m app_timer_sum_rate_9m app_timer_sum_rate_15m app_timer_sum_rate_30m)
latency_p_logs=(latency_seconds_quan_50 latency_seconds_quan_95 latency_seconds_quan_98 latency_seconds_quan_99 latency_seconds_quan_999)
#micrometer_logs=(app_timer_sum app_timer_count app_timer_sum_rate app_timer_count_rate latency_seconds_quan latency_seconds_max)
micrometer_logs=(app_timer_sum app_timer_count ${timer_rate_logs[@]} ${latency_p_logs[@]} latency_seconds_max)
app_calc_metric_logs=(app_timer_rsp_time app_timer_thrpt app_timer_rsp_time_rate_3m app_timer_thrpt_rate_3m)
total_logs=(${podcpulogs[@]} ${podmemlogs[@]} ${micrometer_logs[@]} ${app_calc_metric_logs[@]} cpu_min cpu_max mem_min mem_max)

TOTAL_ITR=$1
RESULTS_DIR_J=$2
sca=$3
WARMUPS=$4
MEASURES=$5
SCRIPT_REPO=$6

#echo "SCALE ,  THROUGHPUT , RESPONSE_TIME , THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m , MAX_RESPONSE_TIME , MEM_USAGE , CPU_USAGE , CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , thrpt_prom_ci , rsp_prom_ci" >> ${RESULTS_DIR_J}/../Metrics-prom.log
#echo "SCALE ,  MEM_RSS , MEM_USAGE " >> ${RESULTS_DIR_J}/../Metrics-mem-prom.log
#echo "SCALE ,  CPU_USAGE" >> ${RESULTS_DIR_J}/../Metrics-cpu-prom.log
#echo "ITR , THROUGHPUT , RESPONSE_TIME , THROUGHPUT_RATE_3m , RESPONSE_TIME_RATE_3m" >> ${RESULTS_DIR_J}/../app-calc-metrics-measure-raw.log
parseResults $1 $2 $3 $4 $5 $6

#cat ${RESULTS_DIR_J}/../Metrics-prom.log
#cat ${RESULTS_DIR_J}/../app-calc-metrics-measure-raw.log
