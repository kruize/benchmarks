#!/bin/bash
#
# Script to build and run the petclinic application and do a test load of the app
# 

function usage() {
	echo
	echo "Usage: [do_setup/use_image]" 
	echo "do_setup baseimage"
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

if [ "$1" == "do_setup" ]; then
	SETUP=true
	IMAGE=$2
	if [ -z "${IMAGE}" ]; then
		IMAGE=adoptopenjdk/openjdk11-openj9:latest
	fi
else
	PETCLINIC_IMAGE=$2
	JMETER_IMAGE=$3
fi

if [ -z "${PETCLINIC_IMAGE}" ]; then
	PETCLINIC_IMAGE=docker.io/kruize/spring-petclinic:2.2.0
fi

if [ -z "${JMETER_IMAGE}" ]; then
	JMETER_IMAGE=docker.io/kruize/jmeter_petclinic:3.1
fi

ROOT_DIR=".."
source ./scripts/petclinic-common.sh
cd ${ROOT_DIR}

# Check if docker and docker-compose are installed
echo -n "Checking prereqs..."
check_prereq
echo "done"

# Get the IP of the current box
get_ip

if [ $SETUP  ]; then
	# Build the petclinic application sources and create the docker image
	echo -n "Building petclinic application..."
	build_petclinic ${IMAGE} ${VERSION}
	PETCLINIC_IMAGE="spring-petclinic"
	echo "done"
# Build the jmeter docker image with the petclinic driver
	echo -n "Building jmeter with petclinic driver..."
	build_jmeter
	echo "done"
else
	echo -n "Pulling the jmeter image..."
	pull_image ${JMETER_IMAGE}
	echo "done"
fi

# Run the application and mongo db
echo -n "Running petclinic with inbuilt db..."
run_petclinic ${PETCLINIC_IMAGE} 
echo "done"

