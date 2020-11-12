#!/bin/bash

ROOT_DIR=".."
source ./acmeair-common.sh
cd ${ROOT_DIR}

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
