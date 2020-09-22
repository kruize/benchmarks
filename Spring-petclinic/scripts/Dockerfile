FROM adoptopenjdk/openjdk11-openj9:latest


COPY --chown=1001:0 spring-petclinic/target/spring-petclinic-*.BUILD-SNAPSHOT.jar /target/spring-petclinic.jar

ENV LOG_DIR=/output 
ENV JVM_ARGS "-Xshareclasses:none"

RUN mkdir /output

RUN java -version
EXPOSE 8080

ENTRYPOINT java ${JVM_ARGS} -jar /target/spring-petclinic.jar

