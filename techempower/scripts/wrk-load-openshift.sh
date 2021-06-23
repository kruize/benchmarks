#!/bin/bash

NAMESPACE="default"
SERVER_HOST=`oc status -n ${NAMESPACE} | grep tfb-qrh | grep port | cut -d " " -f1`
ACCEPT="application/json,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7"
DURATION=15
MAX_CONCURRENCY=512
LEVELS="16 32 64 128 256"

# Run with db url
URL="${SERVER_HOST}/db"
docker run -e server_host=${SERVER_HOST} -e url=${URL} -e accept=${ACCEPT} -e duration=${DURATION} -e max_concurrency=${MAX_CONCURRENCY} -e levels="${LEVELS}" kusumach/tfb.wrk /concurrency.sh

# With json
URL="${SERVER_HOST}/json"
docker run -e server_host=${SERVER_HOST} -e url=${URL} -e accept=${ACCEPT} -e duration=${DURATION} -e max_concurrency=${MAX_CONCURRENCY} -e levels="${LEVELS}" kusumach/tfb.wrk /concurrency.sh

# With fortunes
URL="${SERVER_HOST}/fortunes"
docker run -e server_host=${SERVER_HOST} -e url=${URL} -e accept=${ACCEPT} -e duration=${DURATION} -e max_concurrency=${MAX_CONCURRENCY} -e levels="${LEVELS}" kusumach/tfb.wrk /concurrency.sh

# With queries
URL="${SERVER_HOST}/queries/query="
LEVELS="1 5 10 15 20"
docker run -e server_host=${SERVER_HOST} -e url=${URL} -e accept=${ACCEPT} -e duration=${DURATION} -e max_concurrency=${MAX_CONCURRENCY} -e levels="${LEVELS}" kusumach/tfb.wrk /query.sh

# With plaintext
URL="${SERVER_HOST}/plaintext"
LEVELS="256 512 1024 2048 4096 8192 16384"
PIPELINE=16
docker run -e server_host=${SERVER_HOST} -e url=${URL} -e accept=${ACCEPT} -e duration=${DURATION} -e max_concurrency=${MAX_CONCURRENCY} -e levels="${LEVELS}" -e pipeline=${PIPELINE} kusumach/tfb.wrk /pipeline.sh
