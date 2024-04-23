HYPERFOIL_DIR=$1
RESULTS_LOG=$2
IP_ADDR=$3
DURATION=$4

INTERVAL=900
CONNECTIONS=1
THREAD=1
runtime="${DURATION} seconds"
endtime=$(date -ud "$runtime" +%s)

if [[ ${INTERVAL} -ge ${DURATION} ]] ; then
	INTERVAL=${DURATION}
fi

while [[ $(date -u +%s) -le $endtime ]]
do
	
	cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREAD} --connections=${CONNECTIONS} --duration=${INTERVAL}s http://${IP_ADDR}/db"
        echo "CMD = ${cmd}"
	${cmd}
	sleep 10

	THREAD=$((THREAD+1))
	if [[ ${THREAD} == 56 ]]; then
		THREAD=1
		CONNECTIONS=$((CONNECTIONS+4))
		sleep 120
	fi
	if [[ ${CONNECTIONS} == 512 ]]; then
		CONNECTIONS=1
		THREAD=1
		sleep 200
	fi
done
