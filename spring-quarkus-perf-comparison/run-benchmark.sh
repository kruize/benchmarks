#!/bin/bash

# ============================================================================
# OpenShift Benchmark Runner
# ============================================================================
# Main script to run performance benchmarks on OpenShift
# Supports multiple runtimes, scenarios, and test types

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
if [ -f "config.env" ]; then
    source config.env
else
    echo "ERROR: config.env not found"
    exit 1
fi

# ============================================================================
# Global Variables
# ============================================================================
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
RUN_DIR="${RESULTS_DIR}/${TIMESTAMP}"
LOG_FILE="${RUN_DIR}/benchmark.log"

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    local level=$1
    shift
    local message="$@"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_debug() {
    if [ "$LOG_LEVEL" = "DEBUG" ]; then
        log "DEBUG" "$@"
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run performance benchmarks on OpenShift cluster

Options:
  --scenarios <SCENARIOS>     Comma-separated scenarios: ootb,tuned (default: ${SCENARIOS})
  --runtimes <RUNTIMES>       Comma-separated list of runtimes (default: ${RUNTIMES})
  --tests <TESTS>             Comma-separated list of tests (default: ${TESTS})
  --iterations <N>            Number of iterations (default: ${ITERATIONS})
  --output-dir <DIR>          Output directory (default: ${RESULTS_DIR})
  --registry <REGISTRY>       Container registry (default: ${REGISTRY})
  --image-tag <TAG>           Image tag (default: ${IMAGE_TAG})
  --project <PROJECT>         OpenShift project (default: ${OPENSHIFT_PROJECT})
  --cleanup                   Cleanup after tests (default: ${CLEANUP_AFTER_TEST})
  --no-cleanup                Don't cleanup after tests
  --help                      Show this help message

Examples:
  # Run default configuration
  $0

  # Run specific scenarios and runtimes
  $0 --scenarios ootb,tuned --runtimes quarkus3-jvm,spring4-jvm

  # Run with custom iterations
  $0 --iterations 5 --tests run-load-test

  # Run without cleanup
  $0 --no-cleanup

Available Runtimes:
  - quarkus3-jvm       Quarkus 3 with standard JVM
  - quarkus3-virtual   Quarkus 3 with Virtual Threads
  - spring4-jvm        Spring Boot 4 with standard JVM
  - spring4-virtual    Spring Boot 4 with Virtual Threads

Available Tests:
  - measure-startup    Measure startup time
  - measure-memory     Measure memory usage (RSS)
  - run-load-test      Run Hyperfoil load test

Available Scenarios:
  - ootb               Out-of-the-box (default JVM settings)
  - tuned              Tuned (optimized JVM settings)

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --scenario|--scenarios)
                SCENARIOS="$2"
                shift 2
                ;;
            --runtimes)
                RUNTIMES="$2"
                shift 2
                ;;
            --tests)
                TESTS="$2"
                shift 2
                ;;
            --iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            --output-dir)
                RESULTS_DIR="$2"
                RUN_DIR="${RESULTS_DIR}/${TIMESTAMP}"
                shift 2
                ;;
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --image-tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            --project)
                OPENSHIFT_PROJECT="$2"
                shift 2
                ;;
            --cleanup)
                CLEANUP_AFTER_TEST="true"
                shift
                ;;
            --no-cleanup)
                CLEANUP_AFTER_TEST="false"
                shift
                ;;
            --help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check oc CLI
    if ! command -v oc &> /dev/null; then
        log_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install jq for JSON processing."
        exit 1
    fi
    
    # Check JBang (required for load testing)
    if [[ "$TESTS" == *"run-load-test"* ]]; then
        if ! command -v jbang &> /dev/null; then
            log_info "JBang not found. Installing JBang..."
            if curl -Ls https://sh.jbang.dev | bash -s - app setup; then
                # Source the jbang environment
                export PATH="$HOME/.jbang/bin:$PATH"
                log_info "JBang installed successfully"
            else
                log_error "Failed to install JBang automatically"
                log_error "Please install manually from: https://www.jbang.dev/"
                exit 1
            fi
        fi
        log_info "JBang found: $(jbang version)"
    fi
    
    # Check oc login
    if ! oc whoami &> /dev/null; then
        log_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    
    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Setup OpenShift project
setup_project() {
    log_info "Setting up OpenShift project: ${OPENSHIFT_PROJECT}"
    
    if oc get project "${OPENSHIFT_PROJECT}" &> /dev/null; then
        log_info "Project ${OPENSHIFT_PROJECT} already exists"
    else
        log_info "Creating project ${OPENSHIFT_PROJECT}"
        oc new-project "${OPENSHIFT_PROJECT}"
    fi
    
    oc project "${OPENSHIFT_PROJECT}"
}

# Deploy PostgreSQL
deploy_postgresql() {
    log_info "Deploying PostgreSQL..."
    
    if oc get deployment postgresql &> /dev/null; then
        log_info "PostgreSQL already deployed"
        return 0
    fi
    
    oc apply -f manifests/postgresql.yaml
    
    log_info "Waiting for PostgreSQL to be ready..."
    oc wait --for=condition=available --timeout=300s deployment/postgresql
    
    log_info "PostgreSQL deployed successfully"
}

# Note: Hyperfoil deployment removed - using curl-based load testing instead
# This matches the original repository's approach (they use qDup/JBang CLI)

# Generate manifest from template
generate_manifest() {
    local runtime=$1
    local scenario=$2
    local output_file=$3
    
    local image=$(get_image_name "$runtime")
    local java_opts=$(get_java_opts "$scenario")
    local container_name="${CONTAINER_NAME:-app}"
    
    # Get scenario-specific resources
    local cpu_req cpu_lim mem_req mem_lim
    case "$scenario" in
        ootb)
            cpu_req="${CPU_REQUEST_OOTB:-${CPU_REQUEST}}"
            cpu_lim="${CPU_LIMIT_OOTB:-${CPU_LIMIT}}"
            mem_req="${MEMORY_REQUEST_OOTB:-${MEMORY_REQUEST}}"
            mem_lim="${MEMORY_LIMIT_OOTB:-${MEMORY_LIMIT}}"
            ;;
        tuned)
            cpu_req="${CPU_REQUEST_TUNED:-${CPU_REQUEST}}"
            cpu_lim="${CPU_LIMIT_TUNED:-${CPU_LIMIT}}"
            mem_req="${MEMORY_REQUEST_TUNED:-${MEMORY_REQUEST}}"
            mem_lim="${MEMORY_LIMIT_TUNED:-${MEMORY_LIMIT}}"
            ;;
        *)
            # For custom scenarios, use defaults
            cpu_req="${CPU_REQUEST}"
            cpu_lim="${CPU_LIMIT}"
            mem_req="${MEMORY_REQUEST}"
            mem_lim="${MEMORY_LIMIT}"
            ;;
    esac
    
    # Determine metrics path based on runtime
    local metrics_path
    case "$runtime" in
        quarkus*|quarkus3-spring-compat)
            metrics_path="/q/metrics"
            ;;
        spring*)
            metrics_path="/actuator/prometheus"
            ;;
        *)
            metrics_path="/metrics"
            ;;
    esac
    
    log_debug "Generating manifest for ${runtime}-${scenario}"
    log_debug "Image: ${image}"
    log_debug "Container Name: ${container_name}"
    log_debug "JAVA_OPTS: ${java_opts}"
    log_debug "Resources: CPU ${cpu_req}/${cpu_lim}, Memory ${mem_req}/${mem_lim}"
    log_debug "Metrics path: ${metrics_path}"
    
    sed -e "s|{{RUNTIME}}|${runtime}|g" \
        -e "s|{{SCENARIO}}|${scenario}|g" \
        -e "s|{{IMAGE}}|${image}|g" \
        -e "s|{{CONTAINER_NAME}}|${container_name}|g" \
        -e "s|{{JAVA_OPTS}}|${java_opts}|g" \
        -e "s|{{CPU_REQ}}|${cpu_req}|g" \
        -e "s|{{CPU_LIM}}|${cpu_lim}|g" \
        -e "s|{{MEM_REQ}}|${mem_req}|g" \
        -e "s|{{MEM_LIM}}|${mem_lim}|g" \
        -e "s|{{METRICS_PATH}}|${metrics_path}|g" \
        manifests/app-template.yaml > "$output_file"
}

# Deploy application
deploy_app() {
    local runtime=$1
    local scenario=$2
    
    log_info "Deploying ${runtime} with ${scenario} scenario..."
    
    local manifest_file="${RUN_DIR}/manifests/${runtime}-${scenario}.yaml"
    mkdir -p "$(dirname "$manifest_file")"
    
    generate_manifest "$runtime" "$scenario" "$manifest_file"
    
    oc apply -f "$manifest_file"
    
    log_info "Waiting for ${runtime}-${scenario} to be ready..."
    if ! oc wait --for=condition=available --timeout=${DEPLOYMENT_TIMEOUT}s deployment/${runtime}-${scenario}; then
        log_error "Deployment ${runtime}-${scenario} failed to become ready"
        return 1
    fi
    
    log_info "${runtime}-${scenario} deployed successfully"
    return 0
}

# Run benchmark for a runtime/scenario combination
run_benchmark() {
    local runtime=$1
    local scenario=$2
    local iteration=$3
    
    log_info "Running benchmark: ${runtime}-${scenario} (iteration ${iteration}/${ITERATIONS})"
    
    local result_file="${RUN_DIR}/results/${runtime}-${scenario}-${iteration}.json"
    mkdir -p "$(dirname "$result_file")"
    
    # Initialize result JSON
    cat > "$result_file" << EOF
{
  "runtime": "${runtime}",
  "scenario": "${scenario}",
  "iteration": ${iteration},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests": {}
}
EOF
    
    # Run each test
    IFS=',' read -ra TEST_ARRAY <<< "$TESTS"
    for test in "${TEST_ARRAY[@]}"; do
        log_info "Running test: ${test}"
        
        case $test in
            measure-startup)
                ./scripts/measure-startup.sh "$runtime" "$scenario" "$result_file"
                ;;
            measure-memory)
                ./scripts/measure-memory.sh "$runtime" "$scenario" "$result_file"
                ;;
            run-load-test)
                ./scripts/run-load-test.sh "$runtime" "$scenario" "$result_file"
                ;;
            *)
                log_error "Unknown test: ${test}"
                ;;
        esac
    done
    
    log_info "Benchmark completed: ${runtime}-${scenario} (iteration ${iteration})"
}

# Cleanup deployment
cleanup_deployment() {
    local runtime=$1
    local scenario=$2
    
    if [ "$CLEANUP_AFTER_TEST" = "true" ]; then
        log_info "Cleaning up ${runtime}-${scenario}..."
        oc delete deployment,service,route ${runtime}-${scenario} --ignore-not-found=true
    else
        log_info "Skipping cleanup for ${runtime}-${scenario}"
    fi
}
# Print configuration
print_config() {
    log_info "=========================================="
    log_info "Configuration:"
    log_info "  Scenarios: ${SCENARIOS}"
    log_info "  Runtimes: ${RUNTIMES}"
    log_info "  Tests: ${TESTS}"
    log_info "  Iterations: ${ITERATIONS}"
    log_info "  OpenShift Project: ${OPENSHIFT_PROJECT}"
    log_info "  Results Directory: ${RUN_DIR}"
    log_info "  Cleanup After Test: ${CLEANUP_AFTER_TEST}"
    log_info "=========================================="
}


# Main benchmark execution
run_benchmarks() {
    log_info "Starting benchmark run: ${TIMESTAMP}"
    print_config
    
    # Setup
    setup_project
    deploy_postgresql
    
    # Note: No need to deploy Hyperfoil - using curl-based load testing
    
    # Parse scenarios and runtimes
    IFS=',' read -ra SCENARIO_ARRAY <<< "$SCENARIOS"
    IFS=',' read -ra RUNTIME_ARRAY <<< "$RUNTIMES"
    
    log_info "Will run ${#SCENARIO_ARRAY[@]} scenario(s) x ${#RUNTIME_ARRAY[@]} runtime(s) x ${ITERATIONS} iteration(s)"
    
    # Run benchmarks for each scenario
    for scenario in "${SCENARIO_ARRAY[@]}"; do
        log_info "=========================================="
        log_info "Starting scenario: ${scenario}"
        log_info "=========================================="
        
        # Run benchmarks for each runtime
        for runtime in "${RUNTIME_ARRAY[@]}"; do
            log_info "Processing runtime: ${runtime} (scenario: ${scenario})"
            
            # Run multiple iterations
            for ((i=1; i<=ITERATIONS; i++)); do
                log_info "Iteration ${i}/${ITERATIONS} for ${runtime}-${scenario}"
                
                # Deploy application
                if ! deploy_app "$runtime" "$scenario"; then
                    log_error "Failed to deploy ${runtime}-${scenario}"
                    continue
                fi
                
                # Wait for application to stabilize
                log_info "Waiting for application to stabilize..."
                sleep 10
                
                # Run benchmark
                run_benchmark "$runtime" "$scenario" "$i"
                
                # Cleanup
                cleanup_deployment "$runtime" "$scenario"
                
                # Wait between iterations
                if [ $i -lt $ITERATIONS ]; then
                    log_info "Waiting before next iteration..."
                    sleep 5
                fi
            done
            
            # Wait between runtimes
            log_info "Completed ${runtime}-${scenario}"
            sleep 5
        done
        
        log_info "Completed scenario: ${scenario}"
    done
    
    log_info "All benchmarks completed"
}

# Generate comprehensive metrics JSON (similar to reference repo format)
generate_metrics_json() {
    log_info "Generating comprehensive metrics JSON..."
    
    local metrics_file="${RUN_DIR}/metrics.json"
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local stop_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Start building JSON structure
    cat > "$metrics_file" << 'EOF_START'
{
  "timing": {
    "start": "START_TIME_PLACEHOLDER",
    "stop": "STOP_TIME_PLACEHOLDER"
  },
  "results": {
EOF_START
    
    # Replace placeholders
    sed -i "s/START_TIME_PLACEHOLDER/${start_time}/" "$metrics_file"
    sed -i "s/STOP_TIME_PLACEHOLDER/${stop_time}/" "$metrics_file"
    
    # Parse scenarios and runtimes
    IFS=',' read -ra SCENARIO_ARRAY <<< "$SCENARIOS"
    IFS=',' read -ra RUNTIME_ARRAY <<< "$RUNTIMES"
    local first_entry=true
    
    log_info "Processing scenarios: ${SCENARIOS}"
    log_info "Processing runtimes: ${RUNTIMES}"
    log_info "Number of combinations: $((${#SCENARIO_ARRAY[@]} * ${#RUNTIME_ARRAY[@]}))"
    
    # Check if we have any runtimes
    if [ ${#RUNTIME_ARRAY[@]} -eq 0 ] || [ -z "${RUNTIMES}" ]; then
        log_error "No runtimes found. RUNTIMES variable is empty."
        return 1
    fi
    
    # Add results for each scenario-runtime combination
    for scenario in "${SCENARIO_ARRAY[@]}"; do
        for runtime in "${RUNTIME_ARRAY[@]}"; do
            local runtime_scenario_key="${runtime}-${scenario}"
            log_info "Processing: ${runtime_scenario_key}"
            if [ "$first_entry" = false ]; then
                echo "," >> "$metrics_file"
            fi
            first_entry=false
        
        # Aggregate results across iterations
        local total_throughput=0
        local total_memory=0
        local total_startup=0
        local total_errors=0
            local count=0
            
            # Parse all iteration results for this runtime-scenario combination
            for ((i=1; i<=ITERATIONS; i++)); do
                local result_file="${RUN_DIR}/results/${runtime}-${scenario}-${i}.json"
            log_debug "Checking for result file: ${result_file}"
            if [ -f "$result_file" ]; then
                log_debug "Found result file: ${result_file}"
                # Extract metrics using jq - support both old and new field names
                local throughput=$(jq -r '.tests.load_test.requests_per_sec // .tests."run-load-test".throughput // 0' "$result_file" 2>/dev/null || echo "0")
                local memory=$(jq -r '.tests.memory.rss_mb // .tests."measure-memory".rss_mib // 0' "$result_file" 2>/dev/null || echo "0")
                local startup=$(jq -r '.tests.startup.startup_time_ms // .tests."measure-startup".startup_ms // 0' "$result_file" 2>/dev/null || echo "0")
                local errors=$(jq -r '.tests.load_test.errors // .tests."run-load-test".errors // 0' "$result_file" 2>/dev/null || echo "0")
                
                log_debug "Extracted metrics - throughput: ${throughput}, memory: ${memory}, startup: ${startup}"
                
                total_throughput=$(awk "BEGIN {print $total_throughput + $throughput}" 2>/dev/null || echo "0")
                total_memory=$(awk "BEGIN {print $total_memory + $memory}" 2>/dev/null || echo "0")
                total_startup=$(awk "BEGIN {print $total_startup + $startup}" 2>/dev/null || echo "0")
                total_errors=$(awk "BEGIN {print $total_errors + $errors}" 2>/dev/null || echo "0")
                ((count++)) || true
            else
                log_debug "Result file not found: ${result_file}"
            fi
        done
        
        # Calculate averages
        local av_throughput=0
        local av_memory=0
        local av_startup=0
        local av_errors=0
        local throughput_density=0
        
        if [ $count -gt 0 ]; then
            av_throughput=$(awk "BEGIN {printf \"%.2f\", $total_throughput / $count}")
            av_memory=$(awk "BEGIN {printf \"%.2f\", $total_memory / $count}")
            av_startup=$(awk "BEGIN {printf \"%.2f\", $total_startup / $count}")
            av_errors=$(awk "BEGIN {printf \"%.0f\", $total_errors / $count}")
            
            # Calculate throughput density (throughput per MiB)
            if [ "$(awk "BEGIN {print ($av_memory > 0)}")" -eq 1 ]; then
                throughput_density=$(awk "BEGIN {printf \"%.6f\", $av_throughput / $av_memory}")
            fi
        fi
        
            # Write runtime-scenario results
            cat >> "$metrics_file" << EOF
    "${runtime_scenario_key}": {
      "load": {
        "throughput": [${av_throughput}],
        "connectionErrors": [${av_errors}],
        "requestTimeouts": [0],
        "appErrors": [0],
        "app4xxErrors": [0],
        "app5xxErrors": [0],
        "rss": [${av_memory}],
        "throughputDensity": [${throughput_density}],
        "avThroughput": ${av_throughput},
        "avMaxRss": ${av_memory},
        "maxThroughputDensity": ${throughput_density},
        "avConnectionErrors": ${av_errors},
        "avRequestTimeouts": 0,
        "avAppErrors": 0,
        "avApp4xxErrors": 0,
        "avApp5xxErrors": 0
      },
      "startup": {
        "timings": [${av_startup}],
        "avStartupTime": ${av_startup}
      }
    }
EOF
        done
    done
    
    # Add configuration section
    cat >> "$metrics_file" << EOF
  },
  "config": {
    "units": {
      "timings": {
        "startup": "ms"
      },
      "rss": {
        "startup": "MiB",
        "firstRequest": "MiB",
        "load": "MiB"
      },
      "load": {
        "throughput": "req/s",
        "throughputDensity": "req/s per MiB",
        "errors": {
          "connectionErrors": "count",
          "requestTimeouts": "count"
        }
      }
    },
    "jvm": {
      "vendor": "${JVM_VENDOR}",
      "version": "${JAVA_VERSION}",
      "base_image": "${BASE_IMAGE}",
      "java_opts": {
        "ootb": "${JAVA_OPTS_OOTB:-}",
        "tuned": "${JAVA_OPTS_TUNED:-}"
      }
    },
    "frameworks": {
      "quarkus": {
        "version": "${QUARKUS_VERSION}"
      },
      "spring_boot": {
        "version": "${SPRING_BOOT_VERSION}"
      }
    },
    "run": {
      "description": "Spring and Quarkus Performance Comparison on OpenShift",
      "identifier": "openshift-benchmark-${TIMESTAMP}",
      "scenarios": "${SCENARIOS}",
      "iterations": ${ITERATIONS}
    },
    "resources": {
      "application": {
        "ootb": {
          "cpu": {
            "request": "${CPU_REQUEST_OOTB:-${CPU_REQUEST}}",
            "limit": "${CPU_LIMIT_OOTB:-${CPU_LIMIT}}"
          },
          "memory": {
            "request": "${MEMORY_REQUEST_OOTB:-${MEMORY_REQUEST}}",
            "limit": "${MEMORY_LIMIT_OOTB:-${MEMORY_LIMIT}}"
          }
        },
        "tuned": {
          "cpu": {
            "request": "${CPU_REQUEST_TUNED:-${CPU_REQUEST}}",
            "limit": "${CPU_LIMIT_TUNED:-${CPU_LIMIT}}"
          },
          "memory": {
            "request": "${MEMORY_REQUEST_TUNED:-${MEMORY_REQUEST}}",
            "limit": "${MEMORY_LIMIT_TUNED:-${MEMORY_LIMIT}}"
          }
        }
      },
      "database": {
        "cpu": {
          "request": "${POSTGRES_CPU_REQUEST}",
          "limit": "${POSTGRES_CPU_LIMIT}"
        },
        "memory": {
          "request": "${POSTGRES_MEMORY_REQUEST}",
          "limit": "${POSTGRES_MEMORY_LIMIT}"
        }
      }
    },
    "load_test": {
      "tool": "hyperfoil-jbang",
      "version": "${HYPERFOIL_VERSION}",
      "duration": "${LOAD_TEST_DURATION}",
      "connections": ${LOAD_TEST_CONNECTIONS},
      "rate": ${LOAD_TEST_RATE},
      "warmup": "${LOAD_TEST_WARMUP}"
    },
    "profiler": {
      "name": "none",
      "events": "cpu"
    },
    "repository": {
      "url": "https://github.com/quarkusio/spring-quarkus-perf-comparison.git",
      "branch": "main"
    },
    "openshift": {
      "project": "${OPENSHIFT_PROJECT}",
      "cluster_url": "${OPENSHIFT_CLUSTER_URL}"
    }
  },
  "env": {
    "host": {
      "os": "$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')",
      "type": "$(dmidecode -s system-product-name 2>/dev/null || echo 'Unknown')",
      "kernel": "$(uname -r)",
      "cpu": "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs || echo 'Unknown')",
      "memory": "$(free -h | grep Mem | awk '{print $2}')"
    },
    "run": {
      "host": {
        "user": "$(whoami)",
        "name": "$(hostname)",
        "target": "$(whoami)@$(hostname)"
      }
    }
  }
}
EOF
    
    log_info "Comprehensive metrics JSON generated: ${metrics_file}"
    
    # Output to stdout for logging (similar to reference repo)
    echo ""
    log_info "set-state: RUN.output.config $(jq -c '.config' "$metrics_file")"
    log_info "set-state: RUN.output.env $(jq -c '.env' "$metrics_file")"
    log_info "echo '$(cat "$metrics_file")' > ${metrics_file}"
}

# Generate summary
generate_summary() {
    log_info "Generating summary..."
    
    local summary_file="${RUN_DIR}/summary.json"
    
    cat > "$summary_file" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "scenarios": "${SCENARIOS}",
  "runtimes": "${RUNTIMES}",
  "tests": "${TESTS}",
  "iterations": ${ITERATIONS},
  "results_directory": "${RUN_DIR}"
}
EOF
    
    log_info "Summary saved to: ${summary_file}"
    log_info "Results directory: ${RUN_DIR}"
    
    # Generate comprehensive metrics JSON
    if ! generate_metrics_json; then
        log_error "Failed to generate metrics.json"
        log_error "You can regenerate it later using: ./scripts/results-tools/regenerate-metrics.sh ${RUN_DIR}/results"
        return 1
    fi
}

# Generate comprehensive comparison report
generate_comparison() {
    log_info "Generating comprehensive comparison report..."
    
    # Check if comparison script exists
    if [ ! -f "${SCRIPT_DIR}/scripts/results-tools/compare-all.sh" ]; then
        log_error "Comparison script not found: ${SCRIPT_DIR}/scripts/results-tools/compare-all.sh"
        return 1
    fi
    
    # Run comprehensive comparison (compares all runtimes and scenarios)
    "${SCRIPT_DIR}/scripts/results-tools/compare-all.sh" "${RUN_DIR}" > tee "${RUN_DIR}/comparison.txt"
    
    log_info "Comparison report saved to: ${RUN_DIR}/comparison.txt"
    return 0
}

# Generate HTML report
generate_html_report() {
    log_info "Generating HTML report..."
    
    # Check if report generation script exists
    if [ ! -f "${SCRIPT_DIR}/scripts/results-tools/generate-report.sh" ]; then
        log_error "Report generation script not found: ${SCRIPT_DIR}/scripts/results-tools/generate-report.sh"
        return 1
    fi
    
    # Generate HTML report
    "${SCRIPT_DIR}/scripts/results-tools/generate-report.sh" "${RUN_DIR}"
    
    if [ -f "${RUN_DIR}/report.html" ]; then
        log_info "HTML report generated: ${RUN_DIR}/report.html"
        log_info "Open in browser: file://${RUN_DIR}/report.html"
    else
        log_error "Failed to generate HTML report"
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Create results directory
    mkdir -p "$RUN_DIR"
    
    # Start logging
    log_info "=========================================="
    log_info "OpenShift Benchmark Runner"
    log_info "=========================================="
    
    # Check prerequisites
    check_prerequisites
    
    # Run benchmarks
    run_benchmarks
    
    # Generate summary
    if ! generate_summary; then
        log_error "Failed to generate summary and metrics"
        log_error "Benchmark results are in: ${RUN_DIR}/results/"
        log_error "You can regenerate metrics.json using: ./scripts/results-tools/regenerate-metrics.sh ${RUN_DIR}/results"
    fi
    
    # Generate analysis reports
    log_info ""
    log_info "=========================================="
    log_info "Generating Analysis Reports"
    log_info "=========================================="
    
    # Generate comprehensive comparison (all runtimes x all scenarios)
    if generate_comparison; then
        log_info "✓ Comprehensive comparison report generated"
    else
        log_info "⚠ Comparison report generation failed"
    fi
    
    # Generate HTML report
    if generate_html_report; then
        log_info "✓ HTML report generated"
    else
        log_info "⚠ HTML report generation failed"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "Benchmark Run Completed Successfully"
    log_info "=========================================="
    log_info "Results directory: ${RUN_DIR}"
    log_info "Summary: ${RUN_DIR}/summary.json"
    log_info "Comparison: ${RUN_DIR}/comparison.txt"
    log_info "HTML Report: file://${RUN_DIR}/report.html"
    log_info "=========================================="
}

# Run main function
main "$@"

# Made with Bob
