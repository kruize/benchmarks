#!/bin/bash

# Set default values for parameters if not provided
IP_ADDR="${1:-localhost:8080}"
END_POINT="${2:-db}"
DURATION="${3:-1200}"
THREAD="${4:-56}"
CONNECTIONS="${5:-512}"
INTERVAL=300
runtime="${DURATION} seconds"
endtime=$(date -ud "$runtime" +%s)

if [[ ${INTERVAL} -ge ${DURATION} ]]; then
    INTERVAL=${DURATION}
fi

# Define Hyperfoil directory path within the container
HYPERFOIL_DIR="/opt/hyperfoil/bin"
# Loop until the duration is reached
while [[ $(date -u +%s) -le $endtime ]]; do
    cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREAD} --connections=${CONNECTIONS} --duration=${INTERVAL}s http://${IP_ADDR}/${END_POINT}"
    echo "CMD = ${cmd}"
    ${cmd}
    sleep 1
    THREAD=$((THREAD+1))
    CONNECTIONS=$((CONNECTIONS+4))
done

