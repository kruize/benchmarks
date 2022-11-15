HYPERFOIL_DIR=$1
RESULTS_LOG=$2
IP_ADDR=$3
DURATION=$4
THREAD=$5
CONNECTIONS=$6

INTERVAL=900
runtime="${DURATION} seconds"
endtime=$(date -ud "$runtime" +%s)

while [[ $(date -u +%s) -le $endtime ]]
do
	if [[ ${INTERVAL} -ge ${DURATION} ]] ; then
        	INTERVAL=${DURATION}
	fi

	for (( connection=1; connection <= 512 ; connection++))
	do
		for (( thread=1 ; thread <= 56 ; thread++ ))
		do
			cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREAD} --connections=${CONNECTIONS} --duration=${INTERVAL}s http://${IP_ADDR}/db"
			echo "CMD = ${cmd}"
			${cmd}
			sleep 10
		done
	done
	sleep 300
done
