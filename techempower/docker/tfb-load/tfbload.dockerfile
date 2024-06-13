FROM maven:3.8.4-openjdk-11-slim AS builder

# Install Hyperfoil
RUN apt-get update && \
    apt-get install -y wget unzip && \
    wget https://github.com/Hyperfoil/Hyperfoil/releases/download/hyperfoil-all-0.25.2/hyperfoil-0.25.2.zip && \
    unzip hyperfoil-0.25.2.zip && \
    mv hyperfoil-0.25.2 /opt/hyperfoil && \
    rm hyperfoil-0.25.2.zip

ENV PATH="/opt/hyperfoil/bin:${PATH}"
COPY run_hyperfoil_load.sh /opt/
RUN chmod +x /opt/run_hyperfoil_load.sh
CMD ["/opt/run_hyperfoil_load.sh"]

