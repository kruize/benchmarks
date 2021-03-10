#!/bin/bash

server_host=`oc status | grep quarkus | grep port | cut -d " " -f1`
accept="application/json,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7"
duration=15
max_concurrency=512
levels="16 32 64 128 256"

# Run with db url
url="http://quarkus-resteasy-service-default.apps.kruize.lab.upshift.rdu2.redhat.com/db"
docker run -e server_host=${server_host} -e url=${url} -e accept=${accept} -e duration=${duration} -e max_concurrency=${max_concurrency} -e levels="${levels}" kusumach/tfb.wrk /concurrency.sh

# With json
url="http://quarkus-resteasy-service-default.apps.kruize.lab.upshift.rdu2.redhat.com/json"
docker run -e server_host=${server_host} -e url=${url} -e accept=${accept} -e duration=${duration} -e max_concurrency=${max_concurrency} -e levels="${levels}" kusumach/tfb.wrk /concurrency.sh

# With fortunes
url="http://quarkus-resteasy-service-default.apps.kruize.lab.upshift.rdu2.redhat.com/fortunes"
docker run -e server_host=${server_host} -e url=${url} -e accept=${accept} -e duration=${duration} -e max_concurrency=${max_concurrency} -e levels="${levels}" kusumach/tfb.wrk /concurrency.sh

# With queries
url="http://quarkus-resteasy-service-default.apps.kruize.lab.upshift.rdu2.redhat.com/queries/query="
levels="1 5 10 15 20"
docker run -e server_host=${server_host} -e url=${url} -e accept=${accept} -e duration=${duration} -e max_concurrency=${max_concurrency} -e levels="${levels}" kusumach/tfb.wrk /query.sh

# With plaintext
url="http://quarkus-resteasy-service-default.apps.kruize.lab.upshift.rdu2.redhat.com/plaintext"
levels="256 512 1024 2048 4096 8192 16384"
pipeline=16
docker run -e server_host=${server_host} -e url=${url} -e accept=${accept} -e duration=${duration} -e max_concurrency=${max_concurrency} -e levels="${levels}" -e pipeline=${pipeline} kusumach/tfb.wrk /pipeline.sh
