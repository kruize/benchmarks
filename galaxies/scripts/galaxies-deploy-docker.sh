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
##### Script to run the quarkus application in docker #####
#
CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/galaxies-common.sh

# Iterate through the commandline options
while getopts i:g:-: gopts
do
	case ${gopts} in
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	g)
		GALAXIES_IMAGE="${OPTARG}"
		;;
	esac
done

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${GALAXIES_IMAGE}" ]; then
	GALAXIES_IMAGE=${GALAXIES_DEFAULT_IMAGE}
fi

# Check if docker and docker-compose are installed
echo -n "Checking prereqs..."
check_prereq
echo "done"

if [ "${GALAXIES_IMAGE}" == "${GALAXIES_CUSTOM_IMAGE}" ]; then
	echo -n "Using custom galaxies image ${GALAXIES_IMAGE}..."
	echo " "
fi

count=1
# Run the application 
for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
do
	echo -n "Running galaxies instance ${count} with inbuilt db..."
	run_galaxies ${GALAXIES_IMAGE} ${inst} ${JVM_ARGS}
	echo "done"
	((count=count+1))
done
