#!/bin/bash

# ============================================================================
# Measure Startup Time
# ============================================================================
# Measures the time from pod creation to first successful HTTP request

set -e

# Capture parameters BEFORE sourcing config.env to avoid overwriting
RUNTIME_PARAM=$1
SCENARIO_PARAM=$2
RESULT_FILE=$3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

# Use the parameters passed to the script, not the defaults from config.env
RUNTIME="$RUNTIME_PARAM"
SCENARIO="$SCENARIO_PARAM"

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $@"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $@"
}

measure_startup() {
    local app_name="${RUNTIME}-${SCENARIO}"
    
    log_info "Measuring startup time for ${app_name}..."
    
    # Get pod name
    local pod_name=$(oc get pods -l app=${app_name} -o jsonpath='{.items[0].metadata.name}')
    if [ -z "$pod_name" ]; then
        log_error "Pod not found for ${app_name}"
        return 1
    fi
    
    # Get pod creation time
    local pod_created=$(oc get pod ${pod_name} -o jsonpath='{.metadata.creationTimestamp}')
    local pod_created_epoch=$(date -d "${pod_created}" +%s%3N)
    
    log_info "Pod created at: ${pod_created}"
    
    # Get route URL
    local route_url=$(oc get route ${app_name} -o jsonpath='{.spec.host}')
    if [ -z "$route_url" ]; then
        log_error "Route not found for ${app_name}"
        return 1
    fi
    
    local url="http://${route_url}/fruits"
    log_info "Testing URL: ${url}"
    
    # Wait for first successful request
    local max_attempts=60
    local attempt=0
    local first_success_time=""
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f -m 5 "${url}" > /dev/null 2>&1; then
            first_success_time=$(date +%s%3N)
            log_info "First successful request at attempt ${attempt}"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    if [ -z "$first_success_time" ]; then
        log_error "Application did not respond within ${max_attempts} seconds"
        return 1
    fi
    
    # Calculate startup time
    local startup_time=$((first_success_time - pod_created_epoch))
    
    log_info "Startup time: ${startup_time}ms"
    
    # Update result file
    local temp_file=$(mktemp)
    jq ".tests.startup = {
        \"startup_time_ms\": ${startup_time},
        \"pod_created\": \"${pod_created}\",
        \"first_request_success\": \"$(date -d @$((first_success_time / 1000)) -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" "$RESULT_FILE" > "$temp_file"
    mv "$temp_file" "$RESULT_FILE"
    
    log_info "Startup measurement completed"
    return 0
}

# Main execution
measure_startup

# Made with Bob
