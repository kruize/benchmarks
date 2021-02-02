#!/usr/bin/env bash

if [ $# -ne 2 ]; then
	echo "Usage: $0 IP PORT"
	exit 1
fi

export IP=$1
export PORT=$2

for USERS in 1 5 10 15 20 25 30 35 40
do
  echo "Runnning with ${USERS} users"
	for run in {1..2}
	do
		wrk --threads=${USERS} --connections=${USERS} -d60s http://${IP}:${PORT}/galaxies;
	done
done
