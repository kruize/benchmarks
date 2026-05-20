#!/bin/bash

# ============================================================================
# Measure Memory Usage
# ============================================================================
# Measures RSS (Resident Set Size) memory usage after application startup

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

measure_memory() {
    local app_name="${RUNTIME}-${SCENARIO}"
    
    log_info "Measuring memory usage for ${app_name}..."
    
    # Get pod name
    local pod_name=$(oc get pods -l app=${app_name} -o jsonpath='{.items[0].metadata.name}')
    if [ -z "$pod_name" ]; then
        log_error "Pod not found for ${app_name}"
        return 1
    fi
    
    log_info "Pod: ${pod_name}"
    
    # Wait for application to stabilize
    log_info "Waiting for application to stabilize (30 seconds)..."
    sleep 30
    
    # Get memory metrics from oc adm top (redirect stderr to suppress errors in variable)
    local memory_usage=$(oc adm top pod ${pod_name} --no-headers 2>/dev/null | awk '{print $3}')
    
    if [ -z "$memory_usage" ]; then
        log_error "Failed to get memory metrics from 'oc adm top'"
        log_info "Attempting to get memory from metrics API..."
        # Try alternative method using metrics API
        memory_usage=$(get_memory_from_metrics_api "$pod_name" 2>&1)
    fi
    
    # Convert to MB (handle Mi suffix)
    local memory_mb=$(echo "$memory_usage" | sed 's/Mi//' | grep -oP '^\d+' || echo "0")
    
    # Validate memory_mb is a number
    if ! [[ "$memory_mb" =~ ^[0-9]+$ ]]; then
        log_error "Invalid memory value: $memory_mb, using 0"
        memory_mb=0
    fi
    
    log_info "Memory usage (RSS): ${memory_mb}MB"
    
    # Get additional memory metrics from container stats
    local memory_limit=$(oc get pod ${pod_name} -o jsonpath='{.spec.containers[0].resources.limits.memory}')
    local memory_request=$(oc get pod ${pod_name} -o jsonpath='{.spec.containers[0].resources.requests.memory}')
    
    # Update result file
    local temp_file=$(mktemp)
    jq ".tests.memory = {
        \"rss_mb\": ${memory_mb},
        \"memory_limit\": \"${memory_limit}\",
        \"memory_request\": \"${memory_request}\",
        \"measurement_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" "$RESULT_FILE" > "$temp_file"
    mv "$temp_file" "$RESULT_FILE"
    
    log_info "Memory measurement completed"
    return 0
}

get_memory_from_metrics_api() {
    local pod_name=$1
    
    # Suppress log output to stderr so it doesn't get captured in variable
    >&2 echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Attempting to get memory from metrics API..."
    
    # Try to get memory from pod resource usage
    local memory_bytes=$(oc get --raw /apis/metrics.k8s.io/v1beta1/namespaces/${OPENSHIFT_PROJECT}/pods/${pod_name} 2>/dev/null | jq -r '.containers[0].usage.memory' 2>/dev/null)
    
    if [ -n "$memory_bytes" ] && [ "$memory_bytes" != "null" ]; then
        # Convert from Ki to Mi
        local memory_mi=$(echo "$memory_bytes" | sed 's/Ki$//' | awk '{print int($1/1024)}')
        echo "${memory_mi}"
    else
        >&2 echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] Could not get memory from metrics API, using 0"
        echo "0"
    fi
}

# Main execution
measure_memory

# Made with Bob
