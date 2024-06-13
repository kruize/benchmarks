#!/bin/bash
#
# Copyright (c) 2024, 2024 IBM Corporation, RedHat and others.
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
### Script to run workload for TFB benchmark###

# Set default values for parameters if not provided
IP_ADDR="${1:-localhost:8080}"
END_POINT="${2:-db}"
DURATION="${3:-1200}"
THREADS="${4:-56}"
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
    cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREADS} --connections=${CONNECTIONS} --duration=${INTERVAL}s http://${IP_ADDR}/${END_POINT}"
    echo "CMD = ${cmd}"
    ${cmd}
    sleep 1
    THREADS=$((THREADS+1))
    CONNECTIONS=$((CONNECTIONS+4))
done

