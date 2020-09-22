#!/bin/bash

ROOT_DIR=".."
source ./scripts/petclinic-common.sh

cd ${ROOT_DIR}

docker stop petclinic-app

docker network rm ${NETWORK}

docker rmi spring-petclinic:latest


