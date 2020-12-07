#
# Copyright (c) 2020, 2020 IBM Corporation, RedHat and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
##Docker file to create custom images for petclinic by varying the base image[adoptopenjdk/openjdk11-openj9:latest or adoptopenjdk/openjdk11:latest] ##
#

ARG REPOSITORY

FROM $REPOSITORY

COPY --chown=1001:0 spring-petclinic/target/spring-petclinic-*.BUILD-SNAPSHOT.jar /target/spring-petclinic.jar

ENV LOG_DIR=/output 
ENV JVM_ARGS=

RUN mkdir /output
RUN java -version

EXPOSE 8081

ENTRYPOINT java ${JVM_ARGS} -jar /target/spring-petclinic.jar
