#!/bin/bash
#
# Copyright (c) 2020, 2020 IBM Corporation, RedHat and others.
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
###  Script to build and run the petclinic application and do a test load of the app  ###
# 

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/petclinic-common.sh

# Iterate through the commandline options
while getopts i:p:a:-: gopts
do
	case ${gopts} in
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	p)
		PETCLINIC_IMAGE="${OPTARG}"		
		;;
	a)
		JVM_ARGS="${OPTARG}"
		;;
	esac
done

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${PETCLINIC_IMAGE}" ]; then
	PETCLINIC_IMAGE=${PETCLINIC_DEFAULT_IMAGE}
fi

# Check if docker and docker-compose are installed
echo -n "Checking prereqs..."
check_prereq
echo "done"

if [ "${PETCLINIC_IMAGE}" == "${PETCLINIC_CUSTOM_IMAGE}" ]; then
	echo -n "Using custom petclinic image ${PETCLINIC_IMAGE}..."
	echo " "
fi

# Pull the jmeter image
echo -n "Pulling the jmeter image..." 
pull_image 
echo "done"

count=1
# Run the application 
for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
do 
	echo -n "Running petclinic instance ${count} with inbuilt db..."
	run_petclinic ${PETCLINIC_IMAGE} ${inst} ${JVM_ARGS}
	echo "done"
	((count=count+1))
done

