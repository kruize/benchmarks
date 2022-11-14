FROM registry.access.redhat.com/ubi8/ubi-minimal:8.4
FROM eclipse-temurin:17.0.3_7-jre
WORKDIR /target
ADD https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.14.1/renaissance-gpl-0.14.1.jar /target
COPY renaissance-gpl-0.14.1.jar /target/renaissance-gpl-0.14.1.jar
ADD https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.17.0/jmx_prometheus_javaagent-0.17.0.jar/target
COPY config.yaml config.yaml
ENV JDK_JAVA_OPTIONS=
ENV BENCHMARK=all
ENV TIME_LIMIT=5
ENTRYPOINT java -javaagent:./jmx_prometheus_javaagent-0.17.0.jar=8080:config.yaml ${JDK_JAVA_OPTIONS} -jar /target/renaissance-gpl-0.14.1.jar -t ${TIME_LIMIT} --csv /output/renaissance-output.csv ${BENCHMARK}
Footer
