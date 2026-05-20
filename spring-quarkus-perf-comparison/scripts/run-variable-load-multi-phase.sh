#!/bin/bash

# ============================================================================
# Run Multi-Phase Variable Load Test with Varying Threads
# ============================================================================
# This script simulates real-world load by running multiple sequential
# Hyperfoil tests with different thread and connection configurations.
#
# Unlike a single Hyperfoil run (where threads are global), this approach
# runs separate tests for each phase, allowing threads to scale with load.
#
# Real-world simulation:
# - Low traffic periods: Fewer threads (2-4)
# - Moderate traffic: Medium threads (4-8)
# - Peak traffic: High threads (8-16)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/common-utils.sh"

# Default values
RUNTIME=""
SCENARIO=""
NAMESPACE="benchmark"
URL=""
OUTPUT_DIR="./variable-load-results"
SESSION_ID=""       # Session identifier for grouping related test runs
ITERATION=""        # Iteration number (auto-detected if not specified)
DURATION_MODE="4h"  # 1h, 4h, 24h, or custom
PHASE_DURATION=""   # Custom duration for each phase (e.g., "3m" for testing)
MAX_THREADS=6  # Maximum threads for peak load (used if specific values not set)

# Phase-specific defaults (will be calculated from MAX_THREADS if not set)
LOW_THREADS=""
LOW_CONNECTIONS=""
MED_THREADS=""
MED_CONNECTIONS=""
PEAK_THREADS=""
PEAK_CONNECTIONS=""

# Connection scaling factor (connections per thread)
CONNECTIONS_PER_THREAD=25  # Default: 25 connections per thread

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    cat << EOF
Usage: $0 --runtime <runtime-name> [options]

This script runs multiple sequential Hyperfoil tests with varying thread counts
to simulate real-world load patterns where thread pools scale with traffic.

Required:
  --runtime <name>         Runtime name (e.g., quarkus3-jvm, spring3-virtual)

Optional:
  --scenario <scenario>    Scenario name (ootb or tuned) - auto-discovers URL
  --url <url>              Application URL (alternative to --scenario)
  --namespace <name>       OpenShift namespace (default: benchmark)
  --session-id <id>        Session identifier for grouping related test runs
                           Multiple runs with same session-id are treated as iterations
                           Output: session-{id}/{runtime}-{scenario}-iter{N}.json
  --iteration <num>        Explicit iteration number (auto-detected if not specified)
  --duration <mode>        Duration mode: 1h, 4h, 24h, or custom (default: 4h)
  --phase-duration <time>  Custom duration for each phase (e.g., "3m", "10m", "1h")
                           Only used with --duration custom. Overrides preset durations.
  --max-threads <num>      Maximum threads for peak load (default: 6)
                           Used to calculate low/med/peak if not explicitly set
  --low-threads <num>      Threads for low load phases (default: max_threads/3, min 2)
  --low-connections <num>  Connections for low phases (default: low_threads × 25)
  --med-threads <num>      Threads for medium load phases (default: max_threads/1.5, min 3)
  --med-connections <num>  Connections for medium phases (default: med_threads × 25)
  --peak-threads <num>     Threads for peak load phases (default: max_threads)
  --peak-connections <num> Connections for peak phases (default: peak_threads × 25)
  --connections-per-thread <num>  Connections per thread ratio (default: 25)
  --output-dir <dir>       Output directory (default: ./variable-load-results)
  --help                   Show this help message

Max Threads:
  The --max-threads parameter sets the peak thread count. Other phases scale proportionally:
  - Low phases: max_threads / 3 (min 2)
  - Medium phases: max_threads / 1.5 (min 3)
  - Peak phases: max_threads
  
  Example with --max-threads 6:
    Low: 2 threads, Medium: 4 threads, Peak: 6 threads
  
  Example with --max-threads 12:
    Low: 4 threads, Medium: 8 threads, Peak: 12 threads

Duration Modes:
  1h     - Quick sample test (3 phases, ~1 hour total)
           Threads scale based on --max-threads (default: 2, 6, 2)
           Connections: 50, 400, 100

  4h     - Compressed pattern (5 phases, ~4 hours total)
           Threads scale based on --max-threads (default: 2, 4, 6, 4, 2)
           Connections: 50, 200, 500, 200, 100

  24h    - Full day pattern (11 phases, ~24 hours total)
           Threads scale based on --max-threads (default: 2, 3, 4, 6, 6, 4, 6, 6, 4, 3, 2)
           Connections: 50, 100, 200, 300, 400, 250, 500, 400, 300, 200, 100

  custom - Custom duration for all phases (use with --phase-duration)
           Runs the 4h pattern but with custom phase duration
           Example: --duration custom --phase-duration 3m (runs 5 phases of 3 minutes each)

Session & Iteration Support:
  Sessions group related test runs for comparison and variability analysis.
  - Same session-id = iterations of the same test configuration
  - Different session-ids = different configurations to compare (e.g., OOTB vs Tuned)
  
  Iteration numbers are auto-detected by counting existing files in the session directory.
  You can also specify --iteration explicitly if needed.

Examples:
  # Run 1-hour quick sample test
  $0 --runtime quarkus3-jvm --scenario ootb --duration 1h

  # Run 4-hour test with default settings
  $0 --runtime quarkus3-jvm --scenario ootb

  # Run quick 3-minute test for debugging (5 phases × 3 minutes = 15 minutes total)
  $0 --runtime quarkus3-jvm --scenario ootb --duration custom --phase-duration 3m

  # Run with session tracking (iteration 1)
  $0 --runtime quarkus3-jvm --scenario ootb --session-id baseline

  # Run again with same session (iteration 2 - auto-detected)
  $0 --runtime quarkus3-jvm --scenario ootb --session-id baseline

  # Run tuned version in different session for comparison
  $0 --runtime quarkus3-jvm --scenario tuned --session-id optimized

  # Run with higher max threads (auto-calculates low/med/peak)
  $0 --runtime quarkus3-jvm --scenario ootb --duration 24h --max-threads 12

  # Run with explicit thread and connection values
  $0 --runtime quarkus3-jvm --scenario ootb --duration 4h \
     --low-threads 2 --low-connections 50 \
     --med-threads 6 --med-connections 300 \
     --peak-threads 12 --peak-connections 600

  # Run with custom connections only (threads auto-calculated)
  $0 --runtime quarkus3-jvm --scenario ootb \
     --low-connections 100 --med-connections 400 --peak-connections 800

EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $@"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $@"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $@"
}

log_phase() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [PHASE]${NC} $@"
}

check_jbang() {
    if ! command -v jbang >/dev/null 2>&1; then
        log_error "JBang is not installed"
        log_error "Please install JBang from https://www.jbang.dev/"
        return 1
    fi
    log_info "JBang found: $(jbang version)"
    return 0
}

# Function to run a single phase
# Note: parse_hyperfoil_results() is now in common-utils.sh
run_phase() {
    local phase_name=$1
    local threads=$2
    local connections=$3
    local duration=$4
    local phase_num=$5
    local total_phases=$6
    
    echo ""
    log_phase "========================================="
    log_phase "Phase $phase_num/$total_phases: $phase_name"
    log_phase "========================================="
    log_info "Configuration for this phase:"
    log_info "  Threads:     ${threads}"
    log_info "  Connections: ${connections}"
    log_info "  Duration:    ${duration}"
    log_info "  Target URL:  ${URL}"
    log_phase "========================================="
    
    # Create temporary Hyperfoil config for this phase
    local temp_config=$(mktemp)
    cat > "$temp_config" << EOF
name: ${phase_name}
threads: ${threads}
http:
  - protocol: ${PROTOCOL}
    host: ${HOST}
    port: ${PORT}
    sharedConnections: $((connections + 100))
    allowHttp2: false
    useHttpCache: false
ergonomics:
  repeatCookies: false
  userAgentFromSession: false

phases:
  - main:
      always:
        users: ${connections}
        duration: ${duration}
        maxDuration: ${duration}
        scenario:
          maxRequests: 1
          maxSequences: 1
          orderedSequences:
            - getFruits:
                - httpRequest:
                    GET: /fruits
                    timeout: 30s
                    headers:
                      accept: application/json
EOF
    
    # Create temp directory for this phase
    local tempdir=$(mktemp -d)
    local phase_log="${OUTPUT_DIR}/${RUNTIME}${ITERATION_SUFFIX}_phase${phase_num}_${phase_name}_${TIMESTAMP}.log"
    
    log_info "Running phase $phase_num: $phase_name..."
    log_info "Output: $phase_log"
    
    # Run Hyperfoil
    jbang \
      -Dio.hyperfoil.rootdir=${tempdir} \
      -Dio.hyperfoil.cpu.watchdog.idle.threshold=0.0 \
      run@hyperfoil \
        ${temp_config} \
        &> ${tempdir}/hf.log
    
    # Copy results
    cp ${tempdir}/hf.log "$phase_log"
    
    # Store phase metadata for later parsing (to avoid gaps between phases)
    echo "${phase_num}|${phase_name}|${threads}|${connections}|${duration}|${phase_log}" >> "${OUTPUT_DIR}/.phase_metadata${ITERATION_SUFFIX}_${TIMESTAMP}.txt"
    
    # Cleanup
    rm -f "$temp_config"
    rm -rf "$tempdir"
    
    log_info "Phase $phase_num completed"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --runtime)
            RUNTIME="$2"
            shift 2
            ;;
        --scenario)
            SCENARIO="$2"
            shift 2
            ;;
        --url)
            URL="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --session-id)
            SESSION_ID="$2"
            shift 2
            ;;
        --iteration)
            ITERATION="$2"
            shift 2
            ;;
        --duration)
            DURATION_MODE="$2"
            shift 2
            ;;
        --phase-duration)
            PHASE_DURATION="$2"
            shift 2
            ;;
        --max-threads)
            MAX_THREADS="$2"
            shift 2
            ;;
        --low-threads)
            LOW_THREADS="$2"
            shift 2
            ;;
        --low-connections)
            LOW_CONNECTIONS="$2"
            shift 2
            ;;
        --med-threads)
            MED_THREADS="$2"
            shift 2
            ;;
        --med-connections)
            MED_CONNECTIONS="$2"
            shift 2
            ;;
        --peak-threads)
            PEAK_THREADS="$2"
            shift 2
            ;;
        --peak-connections)
            PEAK_CONNECTIONS="$2"
            shift 2
            ;;
        --connections-per-thread)
            CONNECTIONS_PER_THREAD="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$RUNTIME" ]; then
    log_error "--runtime is required"
    usage
fi

# Validate duration mode
if [ "$DURATION_MODE" != "1h" ] && [ "$DURATION_MODE" != "4h" ] && [ "$DURATION_MODE" != "24h" ] && [ "$DURATION_MODE" != "custom" ]; then
    log_error "Invalid duration mode '$DURATION_MODE'. Must be '1h', '4h', '24h', or 'custom'"
    usage
fi

# Validate phase duration if custom mode
if [ "$DURATION_MODE" = "custom" ] && [ -z "$PHASE_DURATION" ]; then
    log_error "When using --duration custom, you must specify --phase-duration (e.g., '3m', '10m', '1h')"
    usage
fi

# Validate max threads
if ! [[ "$MAX_THREADS" =~ ^[0-9]+$ ]] || [ "$MAX_THREADS" -lt 2 ]; then
    log_error "Invalid max-threads '$MAX_THREADS'. Must be a number >= 2"
    usage
fi

# Auto-discover URL if not provided
if [ -z "$URL" ]; then
    if [ -n "$SCENARIO" ]; then
        log_info "Auto-discovering URL from OpenShift route..."
        
        if [ "$SCENARIO" != "ootb" ] && [ "$SCENARIO" != "tuned" ]; then
            log_error "Invalid scenario '$SCENARIO'. Must be 'ootb' or 'tuned'"
            usage
        fi
        
        ROUTE_NAME="${RUNTIME}-${SCENARIO}"
        ROUTE_URL=$(oc get route "$ROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null)
        
        if [ -n "$ROUTE_URL" ]; then
            URL="http://${ROUTE_URL}"
            log_info "Found route: $URL"
        else
            log_error "Could not find route '$ROUTE_NAME' in namespace '$NAMESPACE'"
            exit 1
        fi
    else
        log_error "Either --url or (--runtime + --scenario) must be provided"
        usage
    fi
fi

# Check JBang
if ! check_jbang; then
    exit 1
fi

# Extract host and port from URL
if [[ $URL =~ ^https?://([^:/]+)(:([0-9]+))?(/.*)?$ ]]; then
    HOST="${BASH_REMATCH[1]}"
    PORT="${BASH_REMATCH[3]}"
    PROTOCOL="${URL%%://*}"
    
    if [ -z "$PORT" ]; then
        if [ "$PROTOCOL" = "https" ]; then
            PORT=443
        else
            PORT=80
        fi
    fi
else
    log_error "Invalid URL format: $URL"
    exit 1
fi

# Handle session-id and iteration logic
if [ -n "$SESSION_ID" ]; then
    # Using session-based organization
    SESSION_DIR="${OUTPUT_DIR}/session-${SESSION_ID}"
    mkdir -p "$SESSION_DIR"
    
    # Auto-detect iteration number if not specified
    if [ -z "$ITERATION" ]; then
        # Count existing summary files for this runtime and scenario in the session
        SCENARIO_SUFFIX="${SCENARIO:-variable-load}"
        EXISTING_COUNT=$(find "$SESSION_DIR" -maxdepth 1 -name "${RUNTIME}-${SCENARIO_SUFFIX}-iter*.json" 2>/dev/null | wc -l)
        ITERATION=$((EXISTING_COUNT + 1))
        log_info "Auto-detected iteration number: $ITERATION"
    fi
    
    # Validate iteration number
    if ! [[ "$ITERATION" =~ ^[0-9]+$ ]] || [ "$ITERATION" -lt 1 ]; then
        log_error "Invalid iteration number '$ITERATION'. Must be a positive integer"
        exit 1
    fi
    
    # Use session directory as output
    OUTPUT_DIR="$SESSION_DIR"
    ITERATION_SUFFIX="-iter${ITERATION}"
    
    log_info "Session ID: $SESSION_ID"
    log_info "Iteration: $ITERATION"
else
    # Traditional timestamp-based organization
    mkdir -p "$OUTPUT_DIR"
    ITERATION_SUFFIX=""
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Calculate thread values
# If PEAK_THREADS is explicitly set, use it as the basis for calculations
# Otherwise, use MAX_THREADS
if [ -n "$PEAK_THREADS" ]; then
    # User specified peak threads explicitly, use it as the reference
    REFERENCE_THREADS=$PEAK_THREADS
else
    # Use MAX_THREADS as reference and set PEAK_THREADS
    REFERENCE_THREADS=$MAX_THREADS
    PEAK_THREADS=$MAX_THREADS
fi

# Calculate LOW_THREADS if not explicitly set
if [ -z "$LOW_THREADS" ]; then
    LOW_THREADS=$(( REFERENCE_THREADS / 3 ))
    [ $LOW_THREADS -lt 2 ] && LOW_THREADS=2
fi

# Calculate MED_THREADS if not explicitly set
if [ -z "$MED_THREADS" ]; then
    MED_THREADS=$(awk "BEGIN {printf \"%.0f\", $REFERENCE_THREADS / 1.5}")
    [ $MED_THREADS -lt 3 ] && MED_THREADS=3
fi

# Calculate connections based on threads if not explicitly set
if [ -z "$LOW_CONNECTIONS" ]; then
    LOW_CONNECTIONS=$(( LOW_THREADS * CONNECTIONS_PER_THREAD ))
fi

if [ -z "$MED_CONNECTIONS" ]; then
    MED_CONNECTIONS=$(( MED_THREADS * CONNECTIONS_PER_THREAD ))
fi

if [ -z "$PEAK_CONNECTIONS" ]; then
    PEAK_CONNECTIONS=$(( PEAK_THREADS * CONNECTIONS_PER_THREAD ))
fi

log_info "========================================="
log_info "Multi-Phase Variable Load Test"
log_info "========================================="
log_info "Runtime:        $RUNTIME"
if [ -n "$SCENARIO" ]; then
    log_info "Scenario:       $SCENARIO"
fi
if [ -n "$SESSION_ID" ]; then
    log_info "Session ID:     $SESSION_ID"
    log_info "Iteration:      $ITERATION"
fi
log_info "Duration Mode:  $DURATION_MODE"
if [ "$DURATION_MODE" = "custom" ]; then
    log_info "Phase Duration: $PHASE_DURATION (per phase)"
fi
log_info "Target URL:     $URL"
log_info ""
log_info "Thread & Connection Configuration:"
log_info "  Connections per thread: ${CONNECTIONS_PER_THREAD}"
log_info "  Low Load:    ${LOW_THREADS} threads, ${LOW_CONNECTIONS} connections ($(( LOW_CONNECTIONS / LOW_THREADS )) per thread)"
log_info "  Medium Load: ${MED_THREADS} threads, ${MED_CONNECTIONS} connections ($(( MED_CONNECTIONS / MED_THREADS )) per thread)"
log_info "  Peak Load:   ${PEAK_THREADS} threads, ${PEAK_CONNECTIONS} connections ($(( PEAK_CONNECTIONS / PEAK_THREADS )) per thread)"
log_info ""
log_info "Output Dir:     $OUTPUT_DIR"
log_info "========================================="
echo ""

# Define phases based on duration mode
if [ "$DURATION_MODE" = "1h" ]; then
    log_info "Running 1-hour quick sample pattern (3 phases)"
    log_info "Total estimated time: ~1 hour"
    echo ""
    
    run_phase "low" $LOW_THREADS $LOW_CONNECTIONS "20m" 1 3
    run_phase "peak" $PEAK_THREADS $PEAK_CONNECTIONS "30m" 2 3
    run_phase "end-low" $LOW_THREADS $LOW_CONNECTIONS "10m" 3 3

elif [ "$DURATION_MODE" = "4h" ]; then
    log_info "Running 4-hour multi-phase pattern (5 phases)"
    log_info "Total estimated time: ~4 hours"
    echo ""
    
    run_phase "low" $LOW_THREADS $LOW_CONNECTIONS "1h" 1 5
    run_phase "ramp-up" $MED_THREADS $MED_CONNECTIONS "30m" 2 5
    run_phase "peak" $PEAK_THREADS $PEAK_CONNECTIONS "1h30m" 3 5
    run_phase "ramp-down" $MED_THREADS $MED_CONNECTIONS "30m" 4 5
    run_phase "end-low" $LOW_THREADS $LOW_CONNECTIONS "30m" 5 5

elif [ "$DURATION_MODE" = "custom" ]; then
    log_info "Running custom duration pattern (5 phases)"
    log_info "Phase duration: $PHASE_DURATION per phase"
    echo ""
    
    run_phase "low" $LOW_THREADS $LOW_CONNECTIONS "$PHASE_DURATION" 1 5
    run_phase "ramp-up" $MED_THREADS $MED_CONNECTIONS "$PHASE_DURATION" 2 5
    run_phase "peak" $PEAK_THREADS $PEAK_CONNECTIONS "$PHASE_DURATION" 3 5
    run_phase "ramp-down" $MED_THREADS $MED_CONNECTIONS "$PHASE_DURATION" 4 5
    run_phase "end-low" $LOW_THREADS $LOW_CONNECTIONS "$PHASE_DURATION" 5 5
    
else  # 24h
    log_info "Running 24-hour multi-phase pattern (11 phases)"
    log_info "Total estimated time: ~24 hours"
    log_info "Running 24-hour multi-phase pattern (11 phases)"
    echo ""
    
    # Calculate intermediate thread values for 24h pattern
    LOW_MED_THREADS=$(awk "BEGIN {printf \"%.0f\", $MAX_THREADS / 2}")
    [ $LOW_MED_THREADS -lt 3 ] && LOW_MED_THREADS=3
    
    # Calculate intermediate values for 24h pattern
    LOW_MED_CONN=$(awk "BEGIN {printf \"%.0f\", ($LOW_CONNECTIONS + $MED_CONNECTIONS) / 2}")
    MED_PEAK_CONN=$(awk "BEGIN {printf \"%.0f\", ($MED_CONNECTIONS + $PEAK_CONNECTIONS) / 2}")
    
    run_phase "night" $LOW_THREADS $LOW_CONNECTIONS "6h" 1 11
    run_phase "morning-ramp-1" $LOW_MED_THREADS $LOW_MED_CONN "1h" 2 11
    run_phase "morning-ramp-2" $MED_THREADS $MED_CONNECTIONS "1h" 3 11
    run_phase "morning-ramp-3" $PEAK_THREADS $MED_PEAK_CONN "1h" 4 11
    run_phase "morning-peak" $PEAK_THREADS $PEAK_CONNECTIONS "3h" 5 11
    run_phase "lunch" $MED_THREADS $MED_CONNECTIONS "2h" 6 11
    run_phase "afternoon-peak" $PEAK_THREADS $PEAK_CONNECTIONS "4h" 7 11
    run_phase "evening-1" $PEAK_THREADS $PEAK_CONNECTIONS "1h" 8 11
    run_phase "evening-2" $MED_THREADS $MED_CONNECTIONS "1h" 9 11
    run_phase "evening-3" $LOW_MED_THREADS $LOW_MED_CONN "1h" 10 11
    run_phase "late-night" $LOW_THREADS $LOW_CONNECTIONS "3h" 11 11
fi

log_info ""
log_info "========================================="
log_info "Multi-Phase Test Completed!"
log_info "========================================="
log_info "All phase logs saved in: $OUTPUT_DIR"
log_info "Runtime: $RUNTIME"
log_info "Duration: $DURATION_MODE"
log_info ""
log_info "Phase logs:"
ls -lh "${OUTPUT_DIR}/${RUNTIME}${ITERATION_SUFFIX}_phase"*"${TIMESTAMP}.log" 2>/dev/null || log_warn "No phase logs found"

# Parse all phase results and generate JSON files
log_info ""
log_info "========================================="
log_info "Parsing Phase Results..."
log_info "========================================="

parse_all_phases() {
    local metadata_file="${OUTPUT_DIR}/.phase_metadata${ITERATION_SUFFIX}_${TIMESTAMP}.txt"
    
    if [ ! -f "$metadata_file" ]; then
        log_error "Phase metadata file not found: $metadata_file"
        return 1
    fi
    
    local phase_jsons=()
    
    # Parse each phase
    while IFS='|' read -r phase_num phase_name threads connections duration phase_log; do
        log_info "Parsing phase $phase_num: $phase_name..."
        
        local phase_json="${OUTPUT_DIR}/${RUNTIME}${ITERATION_SUFFIX}_phase${phase_num}_${phase_name}_${TIMESTAMP}.json"
        
        if parse_hyperfoil_results "$phase_log" "$phase_name" "$threads" "$connections" "$duration" > "$phase_json"; then
            log_info "  ✓ JSON saved: $(basename $phase_json)"
            phase_jsons+=("$phase_json")
        else
            log_error "  ✗ Failed to parse phase $phase_num"
        fi
    done < "$metadata_file"
    
    # Generate summary JSON
    log_info ""
    log_info "Generating summary JSON..."
    
    # Determine summary filename based on session mode
    local summary_json
    if [ -n "$SESSION_ID" ]; then
        # Session mode: use runtime-scenario-iterN.json format
        local scenario_name="${SCENARIO:-variable-load}"
        summary_json="${OUTPUT_DIR}/${RUNTIME}-${scenario_name}-iter${ITERATION}.json"
    else
        # Traditional mode: use runtime_summary_timestamp.json format
        summary_json="${OUTPUT_DIR}/${RUNTIME}_summary_${TIMESTAMP}.json"
    fi
    
    # Try to get JAVA_OPTS and resources from the running pod
    local java_opts=""
    local cpu_request=""
    local cpu_limit=""
    local memory_request=""
    local memory_limit=""
    
    if [ -n "$SCENARIO" ]; then
        local pod_name=$(oc get pods -n "$NAMESPACE" -l app="${RUNTIME}-${SCENARIO}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$pod_name" ]; then
            java_opts=$(oc exec -n "$NAMESPACE" "$pod_name" -- printenv JAVA_OPTS 2>/dev/null || echo "")
            
            # Get resource requests and limits from pod spec
            cpu_request=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
            cpu_limit=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
            memory_request=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
            memory_limit=$(oc get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
        fi
    fi
    
    # Start summary JSON
    cat > "$summary_json" << EOF
{
    "runtime": "${RUNTIME}",
    "scenario": "${SCENARIO:-variable-load}",
    "test_type": "multi-phase-variable-load",
    "duration_mode": "${DURATION_MODE}",
    "timestamp": "${TIMESTAMP}",
EOF
    
    # Add session/iteration info if applicable
    if [ -n "$SESSION_ID" ]; then
        cat >> "$summary_json" << EOF
    "session_id": "${SESSION_ID}",
    "iteration": ${ITERATION},
EOF
    fi
    
    cat >> "$summary_json" << EOF
    "configuration": {
        "max_threads": ${MAX_THREADS},
        "connections_per_thread": ${CONNECTIONS_PER_THREAD},
        "java_opts": "${java_opts}",
        "resources": {
            "cpu": {
                "request": "${cpu_request}",
                "limit": "${cpu_limit}"
            },
            "memory": {
                "request": "${memory_request}",
                "limit": "${memory_limit}"
            }
        }
    },
    "phases": [
EOF
    
    # Add each phase JSON
    local first=true
    for json_file in "${phase_jsons[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$summary_json"
        fi
        cat "$json_file" | sed 's/^/        /' >> "$summary_json"
    done
    
    # Close summary JSON
    cat >> "$summary_json" << EOF

    ]
}
EOF
    
    log_info "  ✓ Summary JSON saved: $(basename $summary_json)"
    
    # Cleanup metadata file
    rm -f "$metadata_file"
    
    log_info ""
    log_info "========================================="
    log_info "JSON Results Generated!"
    log_info "========================================="
    log_info "Summary: $summary_json"
    log_info "Individual phase JSONs: ${#phase_jsons[@]} files"
    log_info ""
    log_info "You can now use these JSON files with:"
    log_info "  - compare-all.sh for text comparison"
    log_info "  - generate-report.sh for HTML reports"
}

parse_all_phases

# Made with Bob
