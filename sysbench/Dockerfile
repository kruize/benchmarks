FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y sysbench && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["sysbench"]

CMD ["cpu", "--threads=1", "--time=100000", "run"]
