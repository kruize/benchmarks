HYPERFOIL WRK FOR TFB BENCHMARK
===============================

Build image:

```
docker build -f ./tfbload.dockerfile .
```

Run docker workload:

```
docker run -it --rm --network=host quay.io/kruizehub/tfb_hyperfoil_load:0.25.2 /opt/run_hyperfoil_load.sh <IPADDR:PORT> <END_POINT> <DURATION_IN_SECONDS> <THREADS> <CONNECTIONS>

Example: docker run -it --rm --network=host quay.io/kusumach/tfb_hyperfoil_load:0.25.2 /opt/run_hyperfoil_load.sh 198.23.12.13:32213 db 300 56 512

```
