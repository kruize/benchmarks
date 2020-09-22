#!/bin/bash
#
# Script to build and run the petclinic application and do a test load of the app
# 

function usage() {
	echo
	echo "Usage: [do_setup/use_image]" 
	exit -1
}

if [ "$#" -lt 1 ]; then
	usage
fi

if [ "$1" == "do_setup" ]; then
         SETUP=true
         #FLAG=1
else
         IMAGE=$2
        # FLAG=2
fi

if [ -z "${IMAGE}" ]; then
       IMAGE=docker.io/kruize/spring-petclinic:2.2.0
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
	build_petclinic
	IMAGE="spring-petclinic"
	echo "done"

fi

# Build the jmeter docker image with the petclinic driver
	echo -n "Building jmeter with petclinic driver..."
	build_jmeter
	echo "done"

# Run the application and mongo db
echo -n "Running petclinic with inbuilt db..."
run_petclinic ${IMAGE} 
echo "done"


# Wait for the app to come up
#sleep 10

# Start the jmeter load
#echo "Starting jmeter load..."
#start_jmeter_load
