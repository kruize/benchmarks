#!/bin/bash
#
# Script to build and run the acmeair application and do a test load of the app
# 
ACMEAIR_IMAGE=$2
JMETER_IMAGE=$3

function usage() {
	echo
	echo "Usage: [use_source_code/use_image]" 
	echo "use_source_code"
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

if [ "$1" == "use_source_code" ]; then
	SETUP=true
fi

if [ -z "${ACMEAIR_IMAGE}" ]; then
	ACMEAIR_IMAGE=docker.io/dinogun/acmeair-monolithic
fi

if [ -z "${JMETER_IMAGE}" ]; then
	JMETER_IMAGE=docker.io/dinogun/jmeter:3.1
fi

source ./scripts/acmeair-common.sh

# Check if docker and docker-compose are installed
echo -n "Checking prereqs..."
check_prereq
echo "done"

# Get the IP of the current box
get_ip

if [ $SETUP  ]; then
	# Build the acmeair application sources and create the docker image
	echo -n "Building acmeair application..."
	build_acmeair
	ACMEAIR_IMAGE=acmeair_mono_service_liberty
	echo "done"

	# Build the acmeair driver sources
	echo -n "Building acmeair driver..."
	build_acmeair_driver
	echo "done"

	# Build the jmeter docker image with the acmeair driver
	echo -n "Building jmeter with acmeair driver..."
	build_jmeter
	echo "done"
else
	echo -n "Pulling the jmeter image..."
	pull_image ${JMETER_IMAGE}
	echo "done"
fi

# Run the application and mongo db
echo -n "Running acmeair and mongo db..."
run_acmeair ${ACMEAIR_IMAGE}
echo "done"
