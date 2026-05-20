#!/bin/bash

# ============================================================================
# Run Load Test - Using JBang + Hyperfoil (Same as Original Repository)
# ============================================================================
# This script runs load tests using JBang + Hyperfoil CLI from the client
# machine, exactly matching the original repository's approach.
# The only difference: targets OpenShift route URL instead of localhost

set -e

# Capture parameters BEFORE sourcing config.env to avoid overwriting
RUNTIME_PARAM=$1
SCENARIO_PARAM=$2
RESULT_FILE=$3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/common-utils.sh"

source "${SCRIPT_DIR}/../config.env"

# Use the parameters passed to the script, not the defaults from config.env
RUNTIME="$RUNTIME_PARAM"
SCENARIO="$SCENARIO_PARAM"

run_load_test() {
    local app_name="${RUNTIME}-${SCENARIO}"
    
    log_info "Running load test for ${app_name} using JBang + Hyperfoil..."
    
    # Check JBang installation
    if ! check_jbang; then
        log_error "Cannot run load test without JBang"
        return 1
    fi
    
    # Get route URL (external access to OpenShift app)
    local route_host=$(oc get route ${app_name} -o jsonpath='{.spec.host}')
    if [ -z "$route_host" ]; then
        log_error "Route not found for ${app_name}"
        return 1
    fi
    
    local url="http://${route_host}"
    log_info "Target URL: ${url}"
    
    # Create temporary directory for Hyperfoil results
    local tempdir=$(mktemp -d)
    log_info "Hyperfoil results directory: ${tempdir}"
    
    # Run Hyperfoil load test using JBang
    # This is EXACTLY the same command as in the original stress.sh
    # Only difference: -PHOST points to OpenShift route instead of localhost
    log_info "Starting Hyperfoil load test..."
    log_info "  Warmup: ${LOAD_TEST_WARMUP}"
    log_info "  Cooldown: 30s"
    log_info "  Load test duration: ${LOAD_TEST_DURATION}"
    log_info "  Connections: ${LOAD_TEST_CONNECTIONS}"
    log_info "  Threads: 2"
    
    # EXACT command from original repository's stress.sh
    # The benchmark file is passed as the last argument to 'run@hyperfoil'
    jbang \
      -Dio.hyperfoil.rootdir=${tempdir} \
      -Dio.hyperfoil.cpu.watchdog.idle.threshold=0.0 \
      run@hyperfoil \
        -PPROTOCOL=http \
        -PHOST=${route_host} \
        -PPORT=80 \
        -PLOAD_DURATION=${LOAD_TEST_DURATION} \
        -PWARMUP_DURATION=${LOAD_TEST_WARMUP} \
        -PWARMUP_PAUSE_DURATION=30s \
        -PCONNECTIONS=${LOAD_TEST_CONNECTIONS} \
        -PTHREADS=2 \
        ${SCRIPT_DIR}/../manifests/fixed-load-hf.yml \
        &> ${tempdir}/hf.log
    
    log_info "Load test completed"
    
    # Display results
    echo "-------------------------------------------------"
    cat ${tempdir}/hf.log
    echo "-------------------------------------------------"
    
    # Parse and save results
    parse_and_update_results "${tempdir}/hf.log"
    
    log_info "Hyperfoil output saved in: ${tempdir}"
    log_info "You can review detailed results in ${tempdir}/hf.log"
    
    return 0
}

# Parse results and update JSON file
# Note: parse_hyperfoil_results() is now in common-utils.sh
parse_and_update_results() {
    local log_file=$1
    
    # Parse using common function
    local parsed_json=$(parse_hyperfoil_results "$log_file" "loadTest" 2 ${LOAD_TEST_CONNECTIONS} "${LOAD_TEST_DURATION}")
    
    # Extract values from parsed JSON
    local throughput=$(echo "$parsed_json" | jq -r '.results.requests_per_sec')
    local total_requests=$(echo "$parsed_json" | jq -r '.results.requests_total')
    local latency_mean=$(echo "$parsed_json" | jq -r '.results.latency_mean_ms')
    local latency_p50=$(echo "$parsed_json" | jq -r '.results.latency_p50_ms')
    local latency_p90=$(echo "$parsed_json" | jq -r '.results.latency_p90_ms')
    local latency_p99=$(echo "$parsed_json" | jq -r '.results.latency_p99_ms')
    local errors=$(echo "$parsed_json" | jq -r '.results.errors')
    local success_2xx=$(echo "$parsed_json" | jq -r '.results.success_2xx')
    local duration_sec=$(echo "$parsed_json" | jq -r '.configuration.duration_seconds')
    
    log_info "Parsed Results:"
    log_info "  Total Requests: ${total_requests}"
    log_info "  Throughput: ${throughput} req/s"
    log_info "  Latency (mean): ${latency_mean}ms"
    log_info "  Latency (p50): ${latency_p50}ms"
    log_info "  Latency (p90): ${latency_p90}ms"
    log_info "  Latency (p99): ${latency_p99}ms"
    log_info "  Errors: ${errors}"
    log_info "  Success (2xx): ${success_2xx}"
    
    # Update result file with load test results
    local temp_file=$(mktemp)
    jq ".tests.load_test = {
        \"tool\": \"hyperfoil-jbang\",
        \"approach\": \"Same as original repository - JBang + Hyperfoil CLI\",
        \"duration_s\": ${duration_sec},
        \"warmup_duration\": \"${LOAD_TEST_WARMUP}\",
        \"cooldown_duration\": \"30s\",
        \"connections\": ${LOAD_TEST_CONNECTIONS},
        \"threads\": 2,
        \"requests_total\": ${total_requests},
        \"requests_per_sec\": ${throughput},
        \"latency_mean_ms\": ${latency_mean},
        \"latency_p50_ms\": ${latency_p50},
        \"latency_p90_ms\": ${latency_p90},
        \"latency_p99_ms\": ${latency_p99},
        \"errors\": ${errors},
        \"success_2xx\": ${success_2xx}
    }" "$RESULT_FILE" > "$temp_file" && mv "$temp_file" "$RESULT_FILE"
}

# Main execution
run_load_test

# Made with Bob
