#!/bin/bash

source ./scripts/acmeair-common.sh

docker stop acmeair-mono-app1
docker stop acmeair-db1

# Clean acmeair monolithic application docker image
pushd acmeair
# Build the application
docker run --rm -v "$PWD":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle clean
popd

# Clean acmeair driver
pushd acmeair-driver
docker run --rm -v "$PWD":/home/gradle/project -w /home/gradle/project dinogun/gradle:5.5.0-jdk8-openj9 gradle clean
popd

docker network rm ${NETWORK}

if [[ "$(docker images -q acmeair_mono_service_liberty:latest 2> /dev/null)" != "" ]]; then
	docker rmi acmeair_mono_service_liberty:latest
fi

if [[ "$(docker images -q jmeter:3.1 2> /dev/null)" != "" ]]; then
	docker rmi jmeter:3.1
fi
