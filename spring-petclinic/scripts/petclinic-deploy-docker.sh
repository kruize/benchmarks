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

TOTAL_INST=$1
PETCLINIC_IMAGE=$2
JVM_ARGS=$3
JMETER_IMAGE=kruize/jmeter_petclinic:3.1

if [ -z "${TOTAL_INST}" ]; then
	TOTAL_INST=1
fi

if [ -z "${PETCLINIC_IMAGE}" ]; then
	PETCLINIC_IMAGE=kruize/spring_petclinic:2.2.0-jdk-11.0.8-openj9-0.21.0
fi

ROOT_DIR=".."
source ./scripts/petclinic-common.sh
pushd ${ROOT_DIR}

# Check if docker and docker-compose are installed
echo -n "Checking prereqs..."
check_prereq
echo "done"

if [ "${PETCLINIC_IMAGE}" == "spring-petclinic:latest" ]; then
	echo -n "Using custom petclinic image ${PETCLINIC_IMAGE}..."
	echo " "
fi

if [ "${JMETER_IMAGE}" == "jmeter_petclinic:3.1" ]; then
	echo -n "Using custom jmeter image ${JMETER_IMAGE}..."
	echo " "
else
	# Pull the jmeter image
	echo -n "Pulling the jmeter image..." 
	pull_image ${JMETER_IMAGE}
	echo "done"
fi
# Run the application 
for(( inst=1; inst<=${TOTAL_INST}; inst++ ))
do 
	echo -n "Running petclinic instance $inst with inbuilt db..."
	run_petclinic ${PETCLINIC_IMAGE} ${inst} ${JVM_ARGS}
	echo "done"
done
