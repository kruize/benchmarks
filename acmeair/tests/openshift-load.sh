#!/bin/bash

ROOT_DIR=..
pushd ${ROOT_DIR}
JMX_FILE="acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx"
NAMESPACE="default"
IP_ADDR=($(oc status --namespace=$NAMESPACE | grep "acmeair" | grep port | cut -d " " -f1 | cut -d "/" -f3))
# User load for each iteration
USER_ARRAY=(10 250 50 100 200)
# Duration of each iteration in seconds
TIME_ARRAY=(300 90 600 450 900)

for iter in `seq 0 4`
do
	echo
	echo "#########################################################################################"
	echo "                             Starting Iteration ${iter}                                  "
	echo "#########################################################################################"
	echo
	
	# Change these appropriately to vary load
	JMETER_LOAD_USERS=${USER_ARRAY[${iter}]}
	JMETER_LOAD_DURATION=${TIME_ARRAY[${iter}]}

	sleep 100

	echo "IP_ADDR = ${IP_ADDR}"

	# Load dummy users into the DB
	wget -O- http://${IP_ADDR}/rest/info/loader/load?numCustomers=${JMETER_LOAD_USERS}

	# Reset the max user id value to default
	git checkout ${JMX_FILE}

	# Calculate maximum user ids based on the USERS values passed
	MAX_USER_ID=$(( JMETER_LOAD_USERS-1 ))

	# Update the jmx value with the max user id
	sed -i 's/"maximumValue">99</"maximumValue">'${MAX_USER_ID}'</' ${JMX_FILE}

	# Run the jmeter load
	echo "Running jmeter load with the following parameters"
	cmd="docker run --rm -v ${PWD}:/opt/app dinogun/jmeter:3.1 jmeter -Jdrivers=${JMETER_LOAD_USERS} -Jduration=${JMETER_LOAD_DURATION} -Jhost=${IP_ADDR} -n -t /opt/app/acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx -DusePureIDs=true -l /opt/app/logs/jmeter.${iter}.log -j /opt/app/logs/jmeter.${iter}.log"


	echo "CMD = ${cmd}"
	$cmd

	sleep 120
done
