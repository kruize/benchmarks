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
###  Script to build the petclinic application  ###
# 

CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/petclinic-common.sh

IMAGE=$1
if [ -z "${IMAGE}" ]; then
	IMAGE=adoptopenjdk/openjdk11-openj9:latest
fi

# Check if docker and docker-compose are installed
echo -n "Checking prereqs..."
check_prereq
echo "done"

# Get the IP of the current box
get_ip

# Build the petclinic application sources and create the docker image
echo -n "Building petclinic application..."
build_petclinic ${IMAGE} 
PETCLINIC_IMAGE="spring-petclinic"
echo "done"

# Build the jmeter docker image with the petclinic driver
echo -n "Building jmeter with petclinic driver..."
build_jmeter
echo "done"
