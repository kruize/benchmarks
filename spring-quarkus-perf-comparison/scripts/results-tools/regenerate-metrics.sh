#!/bin/bash

# ============================================================================
# Regenerate Metrics JSON from Individual Results
# ============================================================================
# This script regenerates the comprehensive metrics.json file from individual
# result JSON files in a results directory.

set -e

RESULTS_DIR=$1

if [ -z "$RESULTS_DIR" ]; then
    echo "Usage: $0 <results-directory>"
    echo ""
    echo "Example: $0 ./results"
    echo ""
    echo "This will scan the results directory for individual result files"
    echo "(e.g., quarkus3-jvm-ootb-1.json) and generate a comprehensive"
    echo "metrics.json file in the same directory."
    exit 1
fi

if [ ! -d "$RESULTS_DIR" ]; then
    echo "ERROR: Results directory not found: $RESULTS_DIR"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $@"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $@"
}

# Detect scenario from filenames
detect_scenario() {
    local first_file=$(ls "$RESULTS_DIR"/*.json 2>/dev/null | head -1)
    if [ -z "$first_file" ]; then
        echo "ootb"
        return
    fi
    
    local basename=$(basename "$first_file")
    # Extract scenario from filename: runtime-scenario-iteration.json
    local scenario=$(echo "$basename" | sed 's/^[^-]*-//' | sed 's/-[^-]*\.json$//')
    echo "$scenario"
}

# Detect runtimes from filenames
detect_runtimes() {
    local runtimes=()
    
    for file in "$RESULTS_DIR"/*.json; do
        if [ -f "$file" ]; then
            local basename=$(basename "$file")
            # Extract runtime from filename: runtime-scenario-iteration.json
            local runtime=$(echo "$basename" | sed 's/-[^-]*-[^-]*\.json$//')
            
            if [[ ! " ${runtimes[@]} " =~ " ${runtime} " ]]; then
                runtimes+=("$runtime")
            fi
        fi
    done
    
    echo "${runtimes[@]}"
}

# Count iterations for a runtime
count_iterations() {
    local runtime=$1
    local scenario=$2
    local count=0
    
    for file in "$RESULTS_DIR"/${runtime}-${scenario}-*.json; do
        if [ -f "$file" ]; then
            ((count++))
        fi
    done
    
    echo $count
}

# Generate comprehensive metrics JSON
generate_metrics_json() {
    log_info "Generating comprehensive metrics JSON..."
    
    local metrics_file="${RESULTS_DIR}/metrics.json"
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local stop_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Detect scenario and runtimes
    SCENARIO=$(detect_scenario)
    RUNTIMES=$(detect_runtimes)
    
    if [ -z "$RUNTIMES" ]; then
        log_error "No result files found in $RESULTS_DIR"
        exit 1
    fi
    
    log_info "Detected scenario: $SCENARIO"
    log_info "Detected runtimes: $RUNTIMES"
    
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
    
    # Parse runtimes
    local runtime_array=($RUNTIMES)
    local first_runtime=true
    local total_iterations=0
    
    # Add results for each runtime
    for runtime in "${runtime_array[@]}"; do
        if [ "$first_runtime" = false ]; then
            echo "," >> "$metrics_file"
        fi
        first_runtime=false
        
        # Count iterations for this runtime
        local iterations=$(count_iterations "$runtime" "$SCENARIO")
        if [ $iterations -gt $total_iterations ]; then
            total_iterations=$iterations
        fi
        
        log_info "Processing runtime: $runtime (${iterations} iterations)"
        
        # Aggregate results across iterations
        local total_throughput=0
        local total_memory=0
        local total_startup=0
        local total_errors=0
        local count=0
        
        # Parse all iteration results for this runtime
        for file in "$RESULTS_DIR"/${runtime}-${SCENARIO}-*.json; do
            if [ -f "$file" ]; then
                # Extract metrics using jq
                local throughput=$(jq -r '.tests.load_test.requests_per_sec // .tests."run-load-test".throughput // 0' "$file" 2>/dev/null || echo "0")
                local memory=$(jq -r '.tests.memory.rss_mb // .tests."measure-memory".rss_mib // 0' "$file" 2>/dev/null || echo "0")
                local startup=$(jq -r '.tests.startup.startup_time_ms // .tests."measure-startup".startup_ms // 0' "$file" 2>/dev/null || echo "0")
                local errors=$(jq -r '.tests.load_test.errors // .tests."run-load-test".errors // 0' "$file" 2>/dev/null || echo "0")
                
                total_throughput=$(awk "BEGIN {print $total_throughput + $throughput}")
                total_memory=$(awk "BEGIN {print $total_memory + $memory}")
                total_startup=$(awk "BEGIN {print $total_startup + $startup}")
                total_errors=$(awk "BEGIN {print $total_errors + $errors}")
                ((count++))
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
        
        log_info "  Throughput: ${av_throughput} req/s"
        log_info "  Memory: ${av_memory} MB"
        log_info "  Startup: ${av_startup} ms"
        
        # Write runtime results
        cat >> "$metrics_file" << EOF
    "${runtime}": {
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
          "connectionErrors": "absolute number",
          "requestTimeouts": "absolute number"
        }
      }
    },
    "jvm": {
      "home": "",
      "version": "unknown",
      "graalvm": {
        "home": "",
        "version": "unknown"
      },
      "memory": "-Xmx512m -Xms512m",
      "args": "-XX:+UseParallelGC -XX:+UseNUMA"
    },
    "quarkus": {
      "version": "unknown",
      "build_config_args": "",
      "native_build_options": ""
    },
    "springboot3": {
      "version": "unknown",
      "native_build_options": ""
    },
    "springboot4": {
      "version": "unknown",
      "native_build_options": ""
    },
    "run": {
      "dropOsFilesystemCaches": "false",
      "useContainerHostNetwork": "false",
      "description": "Spring and Quarkus Performance Comparison - Regenerated",
      "identifier": "regenerated-$(date +%Y%m%d-%H%M%S)"
    },
    "resources": {
      "cpu": {
        "app": "1",
        "db": "1"
      }
    },
    "profiler": {
      "name": "none",
      "events": "cpu"
    },
    "repo": {
      "branch": "main",
      "url": "https://github.com/quarkusio/spring-quarkus-perf-comparison.git",
      "scenario": "${SCENARIO}",
      "scenarioName": "$(echo ${SCENARIO} | sed 's/.*/\u&/')"
    },
    "num_iterations": ${total_iterations}
  },
  "env": {
    "host": {
      "os": "$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')",
      "type": "$(dmidecode -s system-product-name 2>/dev/null || echo 'Unknown')",
      "kernel": "$(uname -r)",
      "memory": "$(free -h 2>/dev/null | grep Mem | awk '{print \$2}' || echo 'Unknown')"
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
    
    # Validate JSON
    if command -v jq &> /dev/null; then
        if jq empty "$metrics_file" 2>/dev/null; then
            log_info "✓ Generated JSON is valid"
        else
            log_error "✗ Generated JSON is invalid"
            return 1
        fi
    fi
    
    echo ""
    log_info "Summary:"
    log_info "  Scenario: ${SCENARIO}"
    log_info "  Runtimes: ${RUNTIMES}"
    log_info "  Iterations: ${total_iterations}"
    log_info "  Output: ${metrics_file}"
}

# Main execution
log_info "Regenerating metrics.json from: $RESULTS_DIR"
generate_metrics_json

echo ""
log_info "Done! You can now use the generated metrics.json file."
log_info "To view a comparison, run:"
echo "  ${SCRIPT_DIR}/compare-all.sh $(dirname $RESULTS_DIR)"

# Made with Bob
