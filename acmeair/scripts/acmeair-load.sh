#!/bin/bash
#
# Script to load test acmeair app
# 

source ./scripts/acmeair-common.sh

function usage() {
	echo
	echo "Usage: $0 docker [Number of iterations of the jmeter load] [ip_adddr / namespace]"
	echo "load_type : docker minikube openshift "
	exit -1
}
LOAD_TYPE=$1
MAX_LOOP=$2
IP_ADDR=$3

if [ -z "${LOAD_TYPE}" ]; then
	usage
fi

if [ -z "${MAX_LOOP}" ]; then
	MAX_LOOP=5
fi

ROOT_DIR=${PWD}
JMX_FILE="${ROOT_DIR}/acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx"
LOG="${ROOT_DIR}/logs"
LOG_FILE="${ROOT_DIR}/logs/jmeter.log"
LOGFILE="${ROOT_DIR}/logs/setup.log"
LOG_DIR="${ROOT_DIR}/logs/acmeair-$(date +%Y%m%d%H%M)"
mkdir -p ${LOG_DIR}

case $LOAD_TYPE in
docker)
	if [ -z "${IP_ADDR}" ]; then
		get_ip
	fi
	if [[ "$(docker images -q jmeter:3.1 2> /dev/null)" == "" ]]; then
		JMETER_FOR_LOAD=docker.io/dinogun/jmeter:3.1
	else
		JMETER_FOR_LOAD="jmeter:3.1"
	fi
	err_exit "Error: Unable to load the jmeter image"
	;;
icp|minikube)
	if [ -z "${IP_ADDR}" ]; then
		IP_ADDR=$(minikube ip)
	fi
	if [[ "$(docker images -q jmeter:3.1 2> /dev/null)" == "" ]]; then
		JMETER_FOR_LOAD=docker.io/dinogun/jmeter:3.1
	else
		JMETER_FOR_LOAD="jmeter:3.1"
	fi
	err_exit "Error: Unable to load the jmeter image"
	;;
openshift)
	if [ -z "${IP_ADDR}" ]; then
		NAMESPACE="default"
		IP_ADDR=($(oc status --namespace=$NAMESPACE | grep "acmeair" | grep port | cut -d " " -f1 | cut -d "/" -f3))
	fi
	JMETER_FOR_LOAD="dinogun/jmeter:3.1"
	err_exit "Error: Unable to load the jmeter image"
	;;
*)
	echo "Load is not determined"
	;;
esac		

for iter in `seq 1 ${MAX_LOOP}`
do
	echo
	echo "#########################################################################################"
	echo "                             Starting Iteration ${iter}                                  "
	echo "#########################################################################################"
	echo
	
	# Change these appropriately to vary load
	JMETER_LOAD_USERS=$(( 150*iter ))
	JMETER_LOAD_DURATION=20
	
	sleep 120 
	
	if [ ${LOAD_TYPE} == "openshift" ]; then
		# Load dummy users into the DB
		wget -O- http://${IP_ADDR}/rest/info/loader/load?numCustomers=${JMETER_LOAD_USERS}  2> ${LOGFILE}
		cmd="docker run --rm -v ${PWD}:/opt/app -it ${JMETER_FOR_LOAD} jmeter -Jdrivers=${JMETER_LOAD_USERS} -Jduration=${JMETER_LOAD_DURATION} -Jhost=${IP_ADDR} -n -t /opt/app/acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx -DusePureIDs=true -l /opt/app/logs/jmeter.${iter}.log -j /opt/app/logs/jmeter.${iter}.log"
	else
		# Load dummy users into the DB
		wget -O- http://${IP_ADDR}:${ACMEAIR_PORT}/rest/info/loader/load?numCustomers=${JMETER_LOAD_USERS} 2> ${LOGFILE}
		cmd="docker run --rm -v ${PWD}:/opt/app -it ${JMETER_FOR_LOAD} jmeter -Jdrivers=${JMETER_LOAD_USERS} -Jduration=${JMETER_LOAD_DURATION} -Jhost=${IP_ADDR} -Jport=${ACMEAIR_PORT} -n -t /opt/app/acmeair-driver/acmeair-jmeter/scripts/AcmeAir.jmx -DusePureIDs=true -l /opt/app/logs/jmeter.log -j /opt/app/logs/jmeter.log"
	fi 
	
	echo " "
	
	# Reset the max user id value to default
	git checkout ${JMX_FILE}

	# Calculate maximum user ids based on the USERS values passed
	MAX_USER_ID=$(( JMETER_LOAD_USERS-1 ))

	# Update the jmx value with the max user id
	sed -i 's/"maximumValue">99</"maximumValue">'${MAX_USER_ID}'</' ${JMX_FILE}
	
	# Run the jmeter load
	echo "Running jmeter load with the following parameters"
	echo "${cmd}"
	$cmd > ${LOG_DIR}/jmeter-${iter}.log
done

#Ret the max user value to previous value
git checkout ${JMX_FILE} > ${LOGFILE}

# Reset the jmx value 
sed -i 's/"maximumValue">${MAX_USER_ID}</"maximumValue">'99'</' ${JMX_FILE}

# Parse the results
parse_acmeair_results ${LOG_DIR} ${MAX_LOOP}
echo "#########################################################################################"
echo "				Displaying the results					       "
echo "#########################################################################################"
cat ${LOG_DIR}/Throughput.log
