HYPERFOIL_DIR=$1
RESULTS_LOG=$2
IP_ADDR=$3
DURATION=$4
THREAD=$5
CONNECTIONS=$6

cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREAD} --connections=${CONNECTIONS} --duration=${DURATION}s http://${IP_ADDR}/db"
echo "CMD = ${cmd}"
${cmd}

