#!/bin/bash

ROOT_DIR=".."
source ./scripts/petclinic-common.sh

cd ${ROOT_DIR}

docker stop petclinic-app

docker network rm ${NETWORK}

if [[ "$(docker images -q spring-petclinic:latest 2> /dev/null)" != "" ]]; then
        docker rmi spring-petclinic:latest
fi



