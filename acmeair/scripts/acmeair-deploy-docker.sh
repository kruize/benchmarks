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
### Script to deploy the one or more instances of acmeair application on docker ###

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/acmeair-common.sh

# Iterate through the commandline options
while getopts i:a:-: gopts
do
	case ${gopts} in
	i)
		SERVER_INSTANCES="${OPTARG}"
		;;
	a)
		ACMEAIR_IMAGE="${OPTARG}"
		;;
	esac
done

if [ -z "${SERVER_INSTANCES}" ]; then
	SERVER_INSTANCES=1
fi

if [ -z "${ACMEAIR_IMAGE}" ]; then
	ACMEAIR_IMAGE=${ACMEAIR_DEFAULT_IMAGE}
fi

# Check if docker and docker-compose are installed
echo -n "Checking prereqs..."
check_prereq
echo "done"

# Get the IP of the current box
get_ip

if [ "${ACMEAIR_IMAGE}" == "${ACMEAIR_CUSTOM_IMAGE}" ]; then
	echo -n "Using custom acmeair image ${ACMEAIR_CUSTOM_IMAGE}..."
	echo " "
fi

# Pull the jmeter image
echo -n "Pulling the jmeter image..."
pull_image 
echo "done"

count=1

# Run the application and mongo db
for(( inst=0; inst<${SERVER_INSTANCES}; inst++ ))
do 
	echo -n "Running ${count} acmeair instance and mongo db..."
	run_acmeair ${ACMEAIR_IMAGE} ${inst}
	echo "done"
	((count=count+1))
done
