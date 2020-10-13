ARG REPOSITORY

FROM $REPOSITORY

COPY --chown=1001:0 spring-petclinic/target/spring-petclinic-*.BUILD-SNAPSHOT.jar /target/spring-petclinic.jar

ENV LOG_DIR=/output 

RUN mkdir /output

RUN java -version
EXPOSE 8080

ENTRYPOINT java -jar /target/spring-petclinic.jar

