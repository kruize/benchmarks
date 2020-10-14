#!/bin/bash

ROOT_DIR=.
pushd ${ROOT_DIR}
# Run the benchmark as
# SCRIPT BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH JMETER_LOAD_USERS JMETER_LOAD_DURATION WARMUPS MEASURES
# Ex of ARGS :  wobbled.os.fyre.ibm.com openshift-monitoring /petclinic/results 400 300 5 3

function usage() {
	echo
	echo "Usage: BENCHMARK_SERVER_NAME NAMESPACE RESULTS_DIR_PATH JMETER_LOAD_USERS JMETER_LOAD_DURATION WARMUPS MEASURES "
	echo " For perf runs: TOTAL_INST TOTAL_ITR RE_DEPLOY MANIFESTS_DIR"
	echo " RE_DEPLOY should be set to true for perf runs"
	exit -1
}

BENCHMARK_SERVER=$1
NAMESPACE=$2
RESULTS_DIR_PATH=$3
JMETER_LOAD_USERS=$4
JMETER_LOAD_DURATION=$5
WARMUPS=$6
MEASURES=$7
TOTAL_INST=$8
TOTAL_ITR=$9
RE_DEPLOY=${10}
MANIFESTS_DIR=${11}

if [ "$#" -lt 4 ]; then
	usage
fi

if [ -z "${JMETER_LOAD_USERS}" ]; then
	JMETER_LOAD_USERS=400
else 
	JMETER_LOAD_USERS=$4
fi

if [ -z "${JMETER_LOAD_USERS}" ]; then
	JMETER_LOAD_DURATION=300
else
	JMETER_LOAD_DURATION=$5
fi

if [ -z "${WARMUPS}" ]; then 
	WARMUPS=5
else
	WARMUPS=$6
fi

if [ -z "${MEASURES}" ]; then
	 MEASURES=3
else
	 MEASURES=$7
fi

if [ -z "${TOTAL_INST}" ]; then
	TOTAL_INST=1
else
	TOTAL_INST=$8
fi

if [ -z "${TOTAL_ITR}" ]; then
	TOTAL_ITR=1
else
	TOTAL_ITR=$9
fi

if [ -z "${RE_DEPLOY}" ]; then
	RE_DEPLOY=false
fi

RESULTS_DIR_ROOT=$RESULTS_DIR_PATH/petclinic-$(date +%Y%m%d%H%M)
mkdir -p $RESULTS_DIR_ROOT

#Adding 10 secs buffer to retrieve CPU and MEM info
CPU_MEM_DURATION=`expr $JMETER_LOAD_DURATION + 10`

throughputlogs=(throughput weberror)
podcpulogs=(cpu cpurequests cpulimits cpureq_in_p cpulimits_in_p)
podmemlogs=(mem memusage memrequests memlimits memreq_in_p memlimit_in_p)
clusterlogs=(c_mem c_cpu c_cpulimits c_cpurequests c_memlimits c_memrequests)
total_logs=(${throughputlogs[@]} ${podcpulogs[@]} ${podmemlogs[@]} ${clusterlogs[@]})

function run_jmeter_workload() {
	# Store results in this file
	RESULTS_LOG=$2
	IP_ADDR=$1
	# Run the jmeter load
	echo "Running jmeter load with the following parameters"
	cmd="docker run  --rm -e JHOST=${IP_ADDR} -e JDURATION=${JMETER_LOAD_DURATION} -e JUSERS=${JMETER_LOAD_USERS} kusumach/petclinic_jmeter_noport:0423"
	echo "CMD = ${cmd}"
	$cmd > $RESULTS_LOG 
}

function run_jmeter_with_scaling()
{
	RESULTS_DIR_J=$1
	TYPE=$2
	RUN=$3
	svc_apis=($(oc status --namespace=$NAMESPACE | grep "petclinic" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	for svc_api  in "${svc_apis[@]}"
	do
		RESULT_LOG=$RESULTS_DIR_J/jmeter-$svc_api-$TYPE-$RUN.log
		#echo "run_jmeter_workload $svc_api $RESULT_LOG"
		run_jmeter_workload $svc_api $RESULT_LOG &
	done	
}

function parseData() {
	TYPE=$1
	TOTAL_RUNS=$2
	ITR=$3
	echo "$TYPE Runs" >> $RESULTS_DIR_J/Throughput-$itr.log
	for (( run=0 ; run<$TOTAL_RUNS ;run++))
	do
		thrp_sum=0
		wer_sum=0
		svc_apis=($(oc status --namespace=$NAMESPACE | grep "petclinic" | grep port | cut -d " " -f1 | cut -d "/" -f3))
		for svc_api  in "${svc_apis[@]}"
		do
			RESULT_LOG=$RESULTS_DIR_P/jmeter-$svc_api-$TYPE-$run.log
			summary=`cat $RESULT_LOG | sed 's%<summary>%%g' | grep "summary = " | tail -n 1`
			throughput=`echo $summary | awk '{print $7}' | sed 's%/s%%g'`
			responsetime=`echo $summary | awk '{print $9}' | sed 's%/s%%g'`
			weberrors=`echo $summary | awk '{print $15}' | sed 's%/s%%g'`
			pages=`echo $summary | awk '{print $3}' | sed 's%/s%%g'`
			thrp_sum=$(echo $thrp_sum+$throughput | bc)
			wer_sum=`expr $wer_sum + $weberrors`
		done
		echo "$run,$thrp_sum,$wer_sum" >> $RESULTS_DIR_J/Throughput-$TYPE-$itr.log
	done
}

function parseCpuMem()  {
	TYPE=$1
	TOTAL_RUNS=$2
	ITR=$3

	echo "$TYPE Runs" >> $RESULTS_DIR_J/Mem-$itr.log
	for (( run=0 ; run<$TOTAL_RUNS ;run++))
	do
		for podcpulog in "${podcpulogs[@]}"
		do
		# Parsing CPU logs for POD
			parsePodCpuLog $podcpulog $TYPE $run $ITR
		done
		for podmemlog in "${podmemlogs[@]}"
		do        
			parsePodMemLog $podmemlog $TYPE $run $ITR
		done
		for clusterlog in "${clusterlogs[@]}"
		do
			parseClusterLog $clusterlog $RESULTS_DIR_P/${clusterlog}-${TYPE}-${run}.json ${clusterlog}-${TYPE}-${itr}.log
		done
	done
}

function parsePodCpuLog()
{
	MODE=$1
	TYPE=$2
	run=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	cpu_sum=0
	t_nodes=($(oc get nodes | grep worker | cut -d " " -f1))
	for t_node in "${t_nodes[@]}"
	do
		CPU_LOG=$RESULTS_DIR_P/${t_node}_$MODE-$TYPE-$run.json
		run_pods=($(cat $CPU_LOG | cut -d ";" -f2 | sort | uniq))
		for run_pod in "${run_pods[@]}"
		do
			cat $CPU_LOG | grep $run_pod | cut -d ";" -f3 | cut -d '"' -f1 > $RESULTS_DIR_P/temp-cpu.log
			each_pod_cpu_avg=$( echo `calcAvg $RESULTS_DIR_P/temp-cpu.log | cut -d "=" -f2`  )
			cpu_sum=$(echo $cpu_sum+$each_pod_cpu_avg | bc)
		done
	done
	echo "$run , $cpu_sum " >> $RESULTS_DIR_J/$RESULTS_LOG
}

function parsePodMemLog()
{
	MODE=$1
	TYPE=$2
	run=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	mem_sum=0
	t_nodes=($(oc get nodes | grep worker | cut -d " " -f1))
	for t_node in "${t_nodes[@]}"
	do
		MEM_LOG=$RESULTS_DIR_P/${t_node}_${MODE}-$TYPE-$run.json
		mem_pods=($(cat $MEM_LOG | cut -d ";" -f2 | sort | uniq))
		for mem_pod in "${mem_pods[@]}"
		do
			cat $MEM_LOG | grep $mem_pod | cut -d ";" -f3 | cut -d '"' -f1 > $RESULTS_DIR_P/temp-mem.log
			if [ $MODE ==  "memreq_in_p" ]  || [ $MODE ==  "memlimit_in_p" ]
			then
				each_pod_mem_avg=$( echo `calcAvg_in_p $RESULTS_DIR_P/temp-mem.log | cut -d "=" -f2`  )
			else
				each_pod_mem_avg=$( echo `calcAvg_inMB $RESULTS_DIR_P/temp-mem.log | cut -d "=" -f2`  )
			fi
			mem_sum=$(echo $mem_sum+$each_pod_mem_avg | bc)
		done
	 done
	echo "$run , $mem_sum " >> $RESULTS_DIR_J/$RESULTS_LOG
}

function parseClusterLog() {
	MODE=$1
	CLUSTER_LOG=$2
	CLUSTER_RESULTS_LOG=$3
	cat $CLUSTER_LOG | cut -d ";" -f2 | cut -d '"' -f1 | grep -Eo '[0-9\.]+' > C_temp.log
	cluster_cpumem=$( echo `calcAvg_in_p C_temp.log | cut -d "=" -f2`  )
	echo "$run , $cluster_cpumem" >> $RESULTS_DIR_J/$CLUSTER_RESULTS_LOG
}

function parseResults() {
	TOTAL_ITR=$1
	RESULTS_DIR_J=$2
	sca=$3
	for (( itr=0 ; itr<$TOTAL_ITR ;itr++))
	do
		RESULTS_DIR_P=$RESULTS_DIR_J/ITR-$itr
		parseData warmup $WARMUPS $itr
		parseData measure $MEASURES $itr
		parseCpuMem warmup $WARMUPS $itr
		parseCpuMem measure $MEASURES $itr

		#Calculte Average and Median of Throughput, Memory and CPU  scores
		cat $RESULTS_DIR_J/Throughput-measure-$itr.log | cut -d "," -f2 >> $RESULTS_DIR_J/throughput-measure-temp.log
		cat $RESULTS_DIR_J/Throughput-measure-$itr.log | cut -d "," -f3 >> $RESULTS_DIR_J/weberror-measure-temp.log
		
		for podcpulog in "${podcpulogs[@]}"
		do
			cat $RESULTS_DIR_J/${podcpulog}-measure-${itr}.log | cut -d "," -f2 >> $RESULTS_DIR_J/${podcpulog}-measure-temp.log
		done
		for podmemlog in "${podmemlogs[@]}"
		do
			cat $RESULTS_DIR_J/${podmemlog}-measure-${itr}.log | cut -d "," -f2 >> $RESULTS_DIR_J/${podmemlog}-measure-temp.log
		done
		for clusterlog in "${clusterlogs[@]}"
		do
			cat $RESULTS_DIR_J/${clusterlog}-measure-${itr}.log | cut -d "," -f2 >> $RESULTS_DIR_J/${clusterlog}-measure-temp.log
		done
	done
	
	for metric in "${total_logs[@]}"
	do
		val=$(echo `calcAvg $RESULTS_DIR_J/${metric}-measure-temp.log | cut -d "=" -f2`)
		eval total_${metric}_avg=$val
	done

	echo "$sca ,  $total_throughput_avg , $total_mem_avg , $total_cpu_avg , $total_c_mem_avg , $total_c_cpu_avg , $total_weberror_avg" >> $RESULTS_DIR_J/../Metrics.log
	echo "$sca ,  $total_mem_avg , $total_memusage_avg , $total_memrequests_avg , $total_memlimits_avg , $total_memreq_in_p_avg , $total_memlimit_in_p_avg " >> $RESULTS_DIR_J/../Metrics-mem.log
	echo "$sca ,  $total_cpu_avg , $total_cpurequests_avg , $total_cpulimits_avg , $total_cpureq_in_p_avg , $total_cpulimits_in_p_avg " >> $RESULTS_DIR_J/../Metrics-cpu.log
	echo "$sca ,  $total_c_cpu_avg , $total_c_cpurequests_avg , $total_c_cpulimits_avg , $total_c_mem_avg , $total_c_memrequests_avg , $total_c_memlimits_avg " >> $RESULTS_DIR_J/../Metrics-cluster.log
}

function calcAvg_inMB()
{
	LOG=$1
	METRIC=$2
	awk '{sum+=$1} END { print "  Average =",sum/NR/1024/1024}' $LOG ;
}

function calcAvg_in_p()
{
	LOG=$1
	METRIC=$2
	awk '{sum+=$1} END { print " % Average =",sum/NR*100}' $LOG ;
}

function calcAvg()
{
	LOG=$1
	METRIC=$2
	awk '{sum+=$1} END { print "  Average =",sum/NR}' $LOG ;
}

#Calculate Median
function calcMedian()
{
	LOG=$1
	sort -n $LOG | awk ' { a[i++]=$1; } END { x=int((i+1)/2); if (x < (i+1)/2) print "  Median =",(a[x-1]+a[x])/2; else print "  Median =",a[x-1]; }'
}

function runItr()
{
	TYPE=$1
	RUNS=$2
	RESULTS_runItr=$3
	for (( run=0; run<${RUNS}; run++ ))
	do
		echo "##### $TYPE $run"
		# Get CPU and MEM info through prometheus queries
		./scripts/getstats-openshift.sh $TYPE-$run $CPU_MEM_DURATION $RESULTS_runItr $BENCHMARK_SERVER petclinic &
		# Run the jmeter workload
		run_jmeter_with_scaling $RESULTS_runItr $TYPE $run
		# Sleep till the jmeter load completes
		sleep $JMETER_LOAD_DURATION
		sleep 40
	done
}

get_recommendations_from_kruize()
{
        TOKEN=`oc whoami --show-token`
        app_list=($(oc get deployments --namespace=$NAMESPACE | grep "petclinic" | cut -d " " -f1))
        for app in "${app_list[@]}"
        do
                curl --silent -k -H "Authorization: Bearer $TOKEN" http://kruize-openshift-monitoring.apps.${BENCHMARK_SERVER}/recommendations?application_name=$app > $RESULTS_DIR_I/${app}-recommendations.log
        done
}
function runIterations() {
	SCALING=$1
	TOTAL_ITR=$2
	WARMUPS=$3
	MEASURES=$4
	RESULTS_DIR_ITR=$5
	#IF we want to use array of users we can use this variable.
	USERS=$JMETER_LOAD_USERS
	for (( itr=0; itr<${TOTAL_ITR}; itr++ ))
	do
		if [ $RE_DEPLOY == "true" ]; then
		./scripts/petclinic-deploy-openshift.sh $BENCHMARK_SERVER $NAMESPACE $MANIFESTS_DIR $RESULTS_DIR_ITR $SCALING
		fi
		# Start the load
		RESULTS_DIR_I=${RESULTS_DIR_ITR}/ITR-$itr
		#mkdir -p $RESULTS_DIR_I
		echo "Running ${WARMUPS} warmups for ${USERS} users"
		runItr warmup $WARMUPS $RESULTS_DIR_I	
		echo "Running ${MEASURES} measures for ${USERS} users"
		runItr measure $MEASURES $RESULTS_DIR_I
		sleep 60
		get_recommendations_from_kruize $RESULTS_DIR_I
	done
}

#TODO Create a function on how many DB inst required for a server. For now,defaulting it to 1
# Scale the instances and run the iterations
echo "Instances , Throughput , TOTAL_PODS_MEM , TOTAL_PODS_CPU , CLUSTER_MEM% , CLUSTER_CPU% , WEB_ERRORS " > ${RESULTS_DIR_ROOT}/Metrics.log
echo "Instances ,  MEM_RSS , MEM_USAGE , MEM_REQ , MEM_LIM , MEM_REQ_IN_P , MEM_LIM_IN_P " > ${RESULTS_DIR_ROOT}/Metrics-mem.log
echo "Instances ,  CPU_USAGE , CPU_REQ , CPU_LIM , CPU_REQ_IN_P , CPU_LIM_IN_P " > ${RESULTS_DIR_ROOT}/Metrics-cpu.log
echo "Instances , CLUSTER_CPU% , C_CPU_REQ% , C_CPU_LIM% , CLUSTER_MEM% , C_MEM_REQ% , C_MEM_LIM% " > ${RESULTS_DIR_ROOT}/Metrics-cluster.log

for (( scale=1; scale<=${TOTAL_INST}; scale++ ))
do
	RESULTS_SC=${RESULTS_DIR_ROOT}/scale_$scale
	#mkdir -p $RESULTS_SC
	echo "RESULTS DIRECTORY is " $RESULTS_DIR_ROOT 
	echo "Running the benchmark with $scale  instances with $TOTAL_ITR iterations having $WARMUPS warmups and $MEASURES measurements"
	runIterations $scale $TOTAL_ITR $WARMUPS $MEASURES $RESULTS_SC
	echo "Parsing results for $scale instances"
	parseResults $TOTAL_ITR $RESULTS_SC $scale
done

