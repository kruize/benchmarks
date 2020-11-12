#!/bin/bash

JMX_FILE="/opt/app/acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx"
LOG_FILE="/opt/app/logs/jmeter.log"

opts="$@"
while (( "$#" ))
do
	case "$1" in
	-Jdrivers)
		USERS=$2;
		break;;
	esac
	shift 1;
done

# Calculate maximum user ids based on the USERS values passed
MAX_USER_ID=$(( USERS-1 ))
# Update the jmx value with the max user id
sed -i 's/"maximumValue">99</"maximumValue">'${MAX_USER_ID}'</' ${JMX_FILE}

echo "Calling jmeter with the following options"
echo "${opts} -n -t ${JMX_FILE} -DusePureIDs=true -l ${LOG_FILE} -j ${LOG_FILE}"
# Call jmeter with the user provided options
jmeter ${opts} -n -t ${JMX_FILE} -DusePureIDs=true -l ${LOG_FILE} -j ${LOG_FILE}
