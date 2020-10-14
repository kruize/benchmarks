#!/bin/bash

ROOT_DIR=".."
source ./scripts/petclinic-common.sh
pushd ${ROOT_DIR}

# stop the petclinic container
docker stop petclinic-app
# remove the petclinic network
docker network rm ${NETWORK}
# remove the petclinic image if present
if [[ "$(docker images -q spring-petclinic:latest 2> /dev/null)" != "" ]]; then
	docker rmi spring-petclinic:latest
fi

