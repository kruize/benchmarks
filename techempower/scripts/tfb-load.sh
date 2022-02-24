#!/bin/bash
#
# Copyright (c) 2021, 2022 Red Hat, IBM Corporation and others.
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
### Script to remove the galaxies setup ###
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/tfb-common.sh

function usage() {
        echo
        echo "Usage: --clustertype=CLUSTER_TYPE[minikube|openshift] [-i SERVER_INSTANCES] [--iter=MAX_LOOP] [-n NAMESPACE] [-a IP_ADDR]"
        exit -1
}

SERVER_INSTANCES=1
MAX_LOOP=4
NAMESPACE=${DEFAULT_NAMESPACE}
END_POINT="db"
THREADS=48
DURATION=20

while getopts c:i:a:n:-: gopts
do
        case ${gopts} in
        -)
                case "${OPTARG}" in
			clustertype=*)
                                CLUSTER_TYPE=${OPTARG#*=}
                                ;;
                        iter=*)
                                MAX_LOOP=${OPTARG#*=}
                                ;;
                esac
                ;;
        i)
                SERVER_INSTANCES="${OPTARG}"
                ;;
        a)
                IP_ADDR="${OPTARG}"
                ;;
        n)
                NAMESPACE="${OPTARG}"
                ;;
        esac
done

if [ -z "${CLUSTER_TYPE}" ]; then
        usage
fi

case ${CLUSTER_TYPE} in
minikube)
        if [ -z "${IP_ADDR}" ]; then
                IP_ADDR=$(minikube ip)
        fi
	TECHEMPOWER_PORT=($(kubectl -n ${NAMESPACE} get svc | grep ${APP_NAME} | tr -s " " | cut -d " " -f5 | cut -d ":" -f2 | cut -d "/" -f1))
        ;;
openshift)
        if [ -z "${IP_ADDR}" ]; then
                IP_ADDR=($(oc status --namespace=${NAMESPACE} | grep ${APP_NAME} | grep port | cut -d " " -f1 | cut -d "/" -f3))
        fi
        ;;
*)
        echo "Load is not determined"
        ;;
esac


LOG_DIR="${PWD}/results/${APP_NAME}-$(date +%Y%m%d%H%M)"
mkdir -p ${LOG_DIR}

## Set-up the load simulator
load_setup

for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
do
	# Check if the application is running
        check_app
	
	SERVER_INSTANCE_PORT=${TECHEMPOWER_PORT[${inst}]}
        for iter in `seq 1 ${MAX_LOOP}`
        do
		# Change these appropriately to vary load
                CONNECTION=$(( 128*iter ))

                echo
                echo "#########################################################################################"
                echo "                             Running with iteration ${iter}                              "
                echo "#########################################################################################"
                echo

               # Run the wrk load
                echo "Running wrk load for ${APP_NAME} instance ${inst} with the following parameters"
		if [[ "${CLUSTER_TYPE}" == "openshift" ]]; then
			cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREADS} --connections=${CONNECTION} --duration=${DURATION}s http://${IP_ADDR}/${END_POINT}"
		else
			cmd="${HYPERFOIL_DIR}/wrk.sh --latency --threads=${THREADS} --connections=${CONNECTION} --duration=${DURATION}s http://${IP_ADDR}:${SERVER_INSTANCE_PORT}/${END_POINT}"
		fi
        	echo "CMD = ${cmd}" >> ${LOGFILE}
	        ${cmd} > ${LOG_DIR}/wrk-${inst}-${iter}.log
                err_exit "can not execute the command"
        done

        # Parse the results
        parse_tfb_results ${LOG_DIR} ${MAX_LOOP}
        echo "#########################################################################################"
        echo "                          Displaying the results                                         "
        echo "#########################################################################################"
        cat ${LOG_DIR}/Throughput.log
done
echo 
echo "To cleanup the deployments, run"
echo "${PWD}/scripts/tfb-cleanup.sh -c ${CLUSTER_TYPE} -n ${NAMESPACE}"
echo

