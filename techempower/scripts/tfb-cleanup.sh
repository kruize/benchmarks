#!/bin/bash
#
# Copyright (c) 2020, 2021 Red Hat, IBM Corporation and others.
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
	echo "Usage: -c CLUSTER_TYPE[docker|minikube|openshift] [-n NAMESPACE]"
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

while getopts c:n:-: gopts
do
	case ${gopts} in
	c)
		CLUSTER_TYPE=${OPTARG}
		;;
	n)
		NAMESPACE="${OPTARG}"		
		;;
	esac
done

if [ -z "${CLUSTER_TYPE}" ]; then
	usage
fi

if [ -z "${NAMESPACE}" ]; then
	NAMESPACE="${DEFAULT_NAMESPACE}"
fi

# Removes the tfb-qrh instances from openshift
# output: Removes the tfb-qrh and tfb-database deployments, services, service monitors and routes
function remove_tfb_openshift() {
	TFB_DEPLOYMENTS=($(${K_EXEC} get deployments --namespace=${NAMESPACE} | grep -e "${APP_NAME}" -e "${APP_DB}" | cut -d " " -f1))

	for de in "${TFB_DEPLOYMENTS[@]}"
	do
		${K_EXEC} delete deployment ${de} --namespace=${NAMESPACE}
	done

	#Delete the services and routes if any
	TFB_SERVICES=($(${K_EXEC} get svc --namespace=${NAMESPACE} | grep -e "${APP_NAME}" -e "${APP_DB}" | cut -d " " -f1))
	for se in "${TFB_SERVICES[@]}"
	do
		${K_EXEC} delete svc ${se} --namespace=${NAMESPACE}
	done
	TFB_ROUTES=($(${K_EXEC} get route --namespace=${NAMESPACE} | grep -e "${APP_NAME}" -e "${APP_DB}" | cut -d " " -f1))
	for ro in "${TFB_ROUTES[@]}"
	do
		${K_EXEC} delete route ${ro} --namespace=${NAMESPACE}
	done
	TFB_SERVICE_MONITORS=($(${K_EXEC} get servicemonitor --namespace=${NAMESPACE} | grep -e "${APP_NAME}" -e "${APP_DB}" | cut -d " " -f1))
	for sm in "${TFB_SERVICE_MONITORS[@]}"
	do
		${K_EXEC} delete servicemonitor ${sm} --namespace=${NAMESPACE}
	done
}

if [ ${CLUSTER_TYPE} == "openshift" ]; then
	K_EXEC="oc"
elif [ ${CLUSTER_TYPE} == "minikube" ]; then
	K_EXEC="kubectl"
fi

echo -n "Removing the tfb instances..."
remove_tfb_openshift >> ${LOGFILE}
echo "done"
