#!/bin/bash

# ============================================================================
# Performance Test: OOTB vs Tuned Comparison for Quarkus 3 JVM
# ============================================================================
# This performance test compares Out-Of-The-Box (OOTB) vs Tuned configurations
# by alternating between them across iterations:
#   Iteration 1: OOTB -> Tuned
#   Iteration 2: OOTB -> Tuned
#
# Each configuration is deployed, load tested, then the next is deployed.
# The URL is automatically discovered based on runtime and scenario.
#
# Test Configuration:
# - Runtime: Quarkus 3 JVM
# - Configurations: OOTB and Tuned (alternating)
# - Iterations: 2 (each config tested twice)
# - Phase Duration: 10 seconds per phase (configurable)
# - Load Pattern: Alternating (low -> medium -> peak)
# - Wait Times: Configurable (stabilization, scenario switch, iteration)
# ============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="${SCRIPT_DIR}/../deploy-app.sh"
BENCHMARK_SCRIPT="${SCRIPT_DIR}/../run-variable-load-multi-phase.sh"
RESULTS_DIR="./variable-load-results"

# Test Parameters
RUNTIME="quarkus3-jvm"
NAMESPACE="quarkus-perf-benchmark"
PHASE_DURATION="10s"
TOTAL_ITERATIONS=2

# Wait Times (in seconds)
STABILIZATION_WAIT=30    # Wait after deployment for app to stabilize
SCENARIO_SWITCH_WAIT=60  # Wait between switching scenarios (OOTB -> Tuned)
ITERATION_WAIT=60        # Wait between iterations

# Alternating Load Configuration
# Low Load Phase
LOW_THREADS=1
LOW_CONNECTIONS=10

# Medium Load Phase
MEDIUM_THREADS=2
MEDIUM_CONNECTIONS=20

# Peak Load Phase
PEAK_THREADS=3
PEAK_CONNECTIONS=30

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $@"
}

log_step() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [STEP]${NC} $@"
}

log_perf() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] [PERF]${NC} $@"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $@"
}

# ============================================================================
# Capture Startup Metrics
# ============================================================================
capture_startup_metrics() {
    local scenario=$1
    local iteration=$2
    local output_file=$3
    
    log_perf "Capturing startup metrics for $scenario..."
    
    local pod_name=$(oc get pods -n "$NAMESPACE" -l app="${RUNTIME}-${scenario}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        log_warn "Could not find pod for ${RUNTIME}-${scenario}"
        return 1
    fi
    
    # Get pod creation time and current time to calculate startup duration
    local pod_start_time=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.startTime}')
    local pod_ready_time=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')
    
    # Get memory usage from pod metrics
    local memory_usage=$(oc top pod "$pod_name" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}')
    local cpu_usage=$(oc top pod "$pod_name" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}')
    
    # Get memory limits and requests
    local memory_limit=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}')
    local memory_request=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}')
    local cpu_limit=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
    local cpu_request=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
    
    # Calculate startup time in seconds
    local startup_seconds=""
    if [ -n "$pod_start_time" ] && [ -n "$pod_ready_time" ]; then
        local start_epoch=$(date -d "$pod_start_time" +%s 2>/dev/null || echo "")
        local ready_epoch=$(date -d "$pod_ready_time" +%s 2>/dev/null || echo "")
        if [ -n "$start_epoch" ] && [ -n "$ready_epoch" ]; then
            startup_seconds=$((ready_epoch - start_epoch))
        fi
    fi
    
    # Create startup metrics JSON
    cat > "$output_file" << EOF
{
  "scenario": "$scenario",
  "iteration": $iteration,
  "pod_name": "$pod_name",
  "startup_time_seconds": ${startup_seconds:-null},
  "pod_start_time": "$pod_start_time",
  "pod_ready_time": "$pod_ready_time",
  "memory": {
    "current_usage": "$memory_usage",
    "limit": "$memory_limit",
    "request": "$memory_request"
  },
  "cpu": {
    "current_usage": "$cpu_usage",
    "limit": "$cpu_limit",
    "request": "$cpu_request"
  },
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "Startup metrics captured:"
    log_info "  Pod: $pod_name"
    log_info "  Startup Time: ${startup_seconds:-N/A} seconds"
    log_info "  Memory Usage: $memory_usage (Limit: $memory_limit, Request: $memory_request)"
    log_info "  CPU Usage: $cpu_usage (Limit: $cpu_limit, Request: $cpu_request)"
    
    return 0
}

# ============================================================================
# Deploy and Run Performance Test for a Configuration
# ============================================================================
deploy_and_test() {
    local scenario=$1
    local iteration=$2
    local session_id=$3
    
    log_step "========================================="
    log_step "Performance Test: ${scenario^^} - Iteration $iteration"
    log_step "========================================="
    
    # Step 1: Deploy the application
    log_perf "Deploying $RUNTIME with $scenario configuration..."
    $DEPLOY_SCRIPT \
        --runtime "$RUNTIME" \
        --scenario "$scenario" \
        --namespace "$NAMESPACE"
    
    log_info "Deployment complete. Waiting ${STABILIZATION_WAIT} seconds for application to stabilize..."
    sleep $STABILIZATION_WAIT
    
    # Step 2: Capture startup metrics
    local startup_metrics_file="${RESULTS_DIR}/session-${session_id}/${RUNTIME}-${scenario}-iter${iteration}-startup.json"
    mkdir -p "$(dirname "$startup_metrics_file")"
    capture_startup_metrics "$scenario" "$iteration" "$startup_metrics_file"
    
    # Step 3: Run variable load performance test
    # The --scenario parameter will auto-discover the URL based on runtime and scenario
    log_perf "Running variable load performance test for $scenario..."
    log_info "URL will be auto-discovered from deployed service: $RUNTIME-$scenario"
    
    $BENCHMARK_SCRIPT \
        --runtime "$RUNTIME" \
        --scenario "$scenario" \
        --session-id "$session_id" \
        --namespace "$NAMESPACE" \
        --duration custom \
        --phase-duration "$PHASE_DURATION" \
        --low-threads $LOW_THREADS \
        --low-connections $LOW_CONNECTIONS \
        --med-threads $MEDIUM_THREADS \
        --med-connections $MEDIUM_CONNECTIONS \
        --peak-threads $PEAK_THREADS \
        --peak-connections $PEAK_CONNECTIONS
    
    log_info "Performance test complete for $scenario - Iteration $iteration"
}

# ============================================================================
# Main Performance Test Execution - Alternating OOTB and Tuned
# ============================================================================
run_alternating_performance_tests() {
    log_step "========================================="
    log_step "Starting Alternating Performance Tests"
    log_step "Pattern: OOTB -> Tuned -> OOTB -> Tuned"
    log_step "========================================="
    
    for iteration in $(seq 1 $TOTAL_ITERATIONS); do
        log_step "========================================="
        log_step "ITERATION $iteration of $TOTAL_ITERATIONS"
        log_step "========================================="
        
        # Run OOTB
        deploy_and_test "ootb" "$iteration" "ootb"
        
        log_info "Waiting ${SCENARIO_SWITCH_WAIT} seconds before switching to Tuned configuration..."
        sleep $SCENARIO_SWITCH_WAIT
        
        # Run Tuned
        deploy_and_test "tuned" "$iteration" "tuned"
        
        # Pause between iterations (except after last iteration)
        if [ $iteration -lt $TOTAL_ITERATIONS ]; then
            log_info "Waiting ${ITERATION_WAIT} seconds before next iteration..."
            sleep $ITERATION_WAIT
        fi
    done
    
    log_step "All alternating performance tests completed!"
}

# ============================================================================
# Analysis Phase 1: Aggregate Performance Results
# ============================================================================
aggregate_performance_results() {
    log_step "========================================="
    log_step "Aggregating Performance Test Results"
    log_step "========================================="
    
    AGGREGATE_SCRIPT="${SCRIPT_DIR}/../results-tools/aggregate-session.sh"
    
    # Aggregate OOTB performance results
    log_info "Aggregating OOTB performance results..."
    if [ -d "${RESULTS_DIR}/session-ootb" ]; then
        $AGGREGATE_SCRIPT --session-dir "${RESULTS_DIR}/session-ootb"
    else
        log_warn "OOTB session directory not found, skipping aggregation"
    fi
    
    # Aggregate Tuned performance results
    log_info "Aggregating Tuned performance results..."
    if [ -d "${RESULTS_DIR}/session-tuned" ]; then
        $AGGREGATE_SCRIPT --session-dir "${RESULTS_DIR}/session-tuned"
    else
        log_warn "Tuned session directory not found, skipping aggregation"
    fi
    
    log_step "Performance results aggregation completed!"
}

# ============================================================================
# Analysis Phase 2: Analyze Performance Variability
# ============================================================================
analyze_performance_variability() {
    log_step "========================================="
    log_step "Analyzing Performance Variability"
    log_step "========================================="
    
    ANALYZE_SCRIPT="${SCRIPT_DIR}/../results-tools/analyze-session.sh"
    
    # Analyze OOTB performance variability
    log_info "Analyzing OOTB performance variability..."
    if [ -d "${RESULTS_DIR}/session-ootb" ]; then
        $ANALYZE_SCRIPT \
            --session-dir "${RESULTS_DIR}/session-ootb" \
            --output "${RESULTS_DIR}/session-ootb/performance-variability-analysis.txt"
    fi
    
    # Analyze Tuned performance variability
    log_info "Analyzing Tuned performance variability..."
    if [ -d "${RESULTS_DIR}/session-tuned" ]; then
        $ANALYZE_SCRIPT \
            --session-dir "${RESULTS_DIR}/session-tuned" \
            --output "${RESULTS_DIR}/session-tuned/performance-variability-analysis.txt"
    fi
    
    log_step "Performance variability analysis completed!"
}

# ============================================================================
# Analysis Phase 3: Compare Performance Between Configurations
# ============================================================================
compare_performance() {
    log_step "========================================="
    log_step "Comparing Performance: OOTB vs Tuned"
    log_step "========================================="
    
    COMPARE_SCRIPT="${SCRIPT_DIR}/../results-tools/compare-sessions.sh"
    
    if [ -d "${RESULTS_DIR}/session-ootb" ] && [ -d "${RESULTS_DIR}/session-tuned" ]; then
        log_info "Generating performance comparison report..."
        $COMPARE_SCRIPT \
            --session-a "${RESULTS_DIR}/session-ootb" \
            --session-b "${RESULTS_DIR}/session-tuned" \
            --session-a-name "OOTB" \
            --session-b-name "Tuned" \
            --output "${RESULTS_DIR}/performance-comparison-ootb-vs-tuned.txt"
        
        # Also generate JSON format for programmatic access
        $COMPARE_SCRIPT \
            --session-a "${RESULTS_DIR}/session-ootb" \
            --session-b "${RESULTS_DIR}/session-tuned" \
            --session-a-name "OOTB" \
            --session-b-name "Tuned" \
            --format json \
            --output "${RESULTS_DIR}/performance-comparison-ootb-vs-tuned.json"
        
        log_step "Performance comparison completed!"
    else
        log_warn "One or both session directories not found, skipping comparison"
    fi
}

# ============================================================================
# Reporting Phase: Generate Performance Reports
# ============================================================================
generate_performance_reports() {
    log_step "========================================="
    log_step "Generating Performance Test Reports"
    log_step "========================================="
    
    REPORT_SCRIPT="${SCRIPT_DIR}/../results-tools/generate-session-report.sh"
    
    # Generate OOTB performance report
    if [ -d "${RESULTS_DIR}/session-ootb" ]; then
        log_info "Generating OOTB performance report..."
        $REPORT_SCRIPT \
            --session-dir "${RESULTS_DIR}/session-ootb" \
            --output "${RESULTS_DIR}/session-ootb/performance-report.html"
    fi
    
    # Generate Tuned performance report
    if [ -d "${RESULTS_DIR}/session-tuned" ]; then
        log_info "Generating Tuned performance report..."
        $REPORT_SCRIPT \
            --session-dir "${RESULTS_DIR}/session-tuned" \
            --output "${RESULTS_DIR}/session-tuned/performance-report.html"
    fi
    
    log_step "Performance reports generated!"
}

# ============================================================================
# Main Performance Test Execution
# ============================================================================
main() {
    log_step "========================================="
    log_step "Performance Test: OOTB vs Tuned"
    log_step "Quarkus 3 JVM - Alternating Configuration"
    log_step "========================================="
    log_info "Runtime: $RUNTIME"
    log_info "Namespace: $NAMESPACE"
    log_info "Iterations: $TOTAL_ITERATIONS (alternating OOTB and Tuned)"
    log_info "Phase Duration: $PHASE_DURATION"
    log_info "Load Pattern: Alternating (Low -> Medium -> Peak)"
    log_info "  - Low:    $LOW_THREADS threads, $LOW_CONNECTIONS connections"
    log_info "  - Medium: $MEDIUM_THREADS threads, $MEDIUM_CONNECTIONS connections"
    log_info "  - Peak:   $PEAK_THREADS threads, $PEAK_CONNECTIONS connections"
    log_info "Results Directory: $RESULTS_DIR"
    log_info ""
    log_info "Test Sequence:"
    log_info "  Iteration 1: Deploy OOTB -> Run Load -> Deploy Tuned -> Run Load"
    log_info "  Iteration 2: Deploy OOTB -> Run Load -> Deploy Tuned -> Run Load"
    log_info ""
    log_info "Note: Application URLs are auto-discovered from deployed services"
    log_info ""
    
    # Check if required scripts exist
    if [ ! -f "$DEPLOY_SCRIPT" ]; then
        echo "ERROR: Deployment script not found: $DEPLOY_SCRIPT"
        exit 1
    fi
    
    if [ ! -f "$BENCHMARK_SCRIPT" ]; then
        echo "ERROR: Benchmark script not found: $BENCHMARK_SCRIPT"
        exit 1
    fi
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    # Execute performance test workflow
    run_alternating_performance_tests
    echo ""
    
    aggregate_performance_results
    echo ""
    
    analyze_performance_variability
    echo ""
    
    compare_performance
    echo ""
    
    generate_performance_reports
    echo ""
    
    # Performance Test Summary
    log_step "========================================="
    log_step "Performance Test Execution Complete!"
    log_step "========================================="
    log_info "Results Location: $RESULTS_DIR"
    log_info ""
    log_info "Performance Test Artifacts:"
    log_info "  OOTB Configuration:"
    log_info "    - ${RESULTS_DIR}/session-ootb/aggregated.json"
    log_info "    - ${RESULTS_DIR}/session-ootb/performance-variability-analysis.txt"
    log_info "    - ${RESULTS_DIR}/session-ootb/performance-report.html"
    log_info "    - ${RESULTS_DIR}/session-ootb/*-startup.json (startup metrics per iteration)"
    log_info ""
    log_info "  Tuned Configuration:"
    log_info "    - ${RESULTS_DIR}/session-tuned/aggregated.json"
    log_info "    - ${RESULTS_DIR}/session-tuned/performance-variability-analysis.txt"
    log_info "    - ${RESULTS_DIR}/session-tuned/performance-report.html"
    log_info "    - ${RESULTS_DIR}/session-tuned/*-startup.json (startup metrics per iteration)"
    log_info ""
    log_info "  Performance Comparison:"
    log_info "    - ${RESULTS_DIR}/performance-comparison-ootb-vs-tuned.txt"
    log_info "    - ${RESULTS_DIR}/performance-comparison-ootb-vs-tuned.json"
    log_info ""
    log_info "Next Steps:"
    log_info "  1. Review startup metrics to compare initialization time and memory footprint"
    log_info "  2. Review variability analysis to ensure CV% < 10% for reliable results"
    log_info "  3. Check performance comparison report for throughput/latency differences"
    log_info "  4. Open HTML reports in browser for detailed performance metrics"
    log_info "  5. Analyze phase-by-phase performance under different load conditions"
    log_step "========================================="
}

# Run main performance test
main "$@"

# Made with Bob
