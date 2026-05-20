#!/bin/bash

# ============================================================================
# Comprehensive Comparison Script
# ============================================================================
# Compares ALL runtimes across ALL scenarios in a matrix format

set -e

RESULTS_DIR=$1

if [ -z "$RESULTS_DIR" ]; then
    echo "Usage: $0 <results-directory>"
    exit 1
fi

# Remove trailing slash if present
RESULTS_DIR="${RESULTS_DIR%/}"

# If path ends with /results, use it as is, otherwise append /results
if [[ "$RESULTS_DIR" == */results ]]; then
    RESULTS_FILES_DIR="$RESULTS_DIR"
else
    RESULTS_FILES_DIR="$RESULTS_DIR/results"
fi

if [ ! -d "$RESULTS_FILES_DIR" ]; then
    echo "ERROR: Results directory not found: $RESULTS_FILES_DIR"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $@"
}

# Calculate statistics for a metric
calculate_stats() {
    local values=("$@")
    local count=${#values[@]}
    
    if [ $count -eq 0 ]; then
        echo "0 0 0 0 0"
        return
    fi
    
    # Calculate sum
    local sum=0
    for val in "${values[@]}"; do
        sum=$(awk "BEGIN {print $sum + $val}")
    done
    
    # Calculate mean
    local mean=$(awk "BEGIN {printf \"%.2f\", $sum / $count}")
    
    # Sort values for median
    IFS=$'\n' sorted=($(sort -n <<<"${values[*]}"))
    unset IFS
    
    # Calculate median
    local median
    if [ $((count % 2)) -eq 0 ]; then
        local mid=$((count / 2))
        median=$(awk "BEGIN {printf \"%.2f\", (${sorted[$mid-1]} + ${sorted[$mid]}) / 2}")
    else
        local mid=$((count / 2))
        median=${sorted[$mid]}
    fi
    
    # Calculate min and max
    local min=${sorted[0]}
    local max=${sorted[$count-1]}
    
    # Calculate standard deviation
    local variance=0
    for val in "${values[@]}"; do
        local diff=$(awk "BEGIN {print $val - $mean}")
        local sq=$(awk "BEGIN {print $diff * $diff}")
        variance=$(awk "BEGIN {print $variance + $sq}")
    done
    variance=$(awk "BEGIN {printf \"%.2f\", $variance / $count}")
    local stddev=$(awk "BEGIN {printf \"%.2f\", sqrt($variance)}")
    
    echo "$mean $median $stddev $min $max"
}

# Extract metric from result files
extract_metric() {
    local runtime=$1
    local scenario=$2
    local metric_path=$3
    
    local values=()
    
    for file in "$RESULTS_DIR"/results/${runtime}-${scenario}-*.json; do
        if [ -f "$file" ]; then
            local value=$(jq -r "$metric_path" "$file" 2>/dev/null)
            if [ "$value" != "null" ] && [ -n "$value" ]; then
                values+=($value)
            fi
        fi
    done
    
    echo "${values[@]}"
}

# Get mean value for a metric
get_mean() {
    local runtime=$1
    local scenario=$2
    local metric_path=$3
    
    local values=($(extract_metric "$runtime" "$scenario" "$metric_path"))
    if [ ${#values[@]} -eq 0 ]; then
        echo "N/A"
        return
    fi
    
    local stats=($(calculate_stats "${values[@]}"))
    echo "${stats[0]}"
}

# Calculate improvement percentage
calculate_improvement() {
    local baseline=$1
    local optimized=$2
    
    if [ "$baseline" = "0" ] || [ -z "$baseline" ] || [ "$baseline" = "0.00" ] || [ "$baseline" = "N/A" ] || [ "$optimized" = "N/A" ]; then
        echo "N/A"
        return
    fi
    
    local improvement=$(awk "BEGIN {printf \"%.2f\", (($baseline - $optimized) / $baseline) * 100}")
    printf "%+.2f%%" "$improvement"
}

# Print comparison matrix for a metric
print_metric_matrix() {
    local metric_name=$1
    local metric_path=$2
    local lower_is_better=$3
    
    echo ""
    echo "================================================================================"
    echo "$metric_name"
    echo "================================================================================"
    
    # Print header
    printf "%-25s" "Runtime"
    for scenario in "${SCENARIOS[@]}"; do
        printf " | %-15s" "$scenario"
    done
    echo ""
    printf "%s\n" "$(printf '=%.0s' {1..100})"
    
    # Print each runtime's values across scenarios
    for runtime in "${RUNTIMES[@]}"; do
        printf "%-25s" "$runtime"
        for scenario in "${SCENARIOS[@]}"; do
            local value=$(get_mean "$runtime" "$scenario" "$metric_path")
            printf " | %-15s" "$value"
        done
        echo ""
    done
    
    # If we have multiple scenarios, show improvement comparisons
    if [ ${#SCENARIOS[@]} -gt 1 ]; then
        echo ""
        echo "Improvements (comparing scenarios):"
        
        # Compare first scenario vs others
        local base_scenario="${SCENARIOS[0]}"
        for ((i=1; i<${#SCENARIOS[@]}; i++)); do
            local compare_scenario="${SCENARIOS[$i]}"
            echo ""
            echo "  ${base_scenario} → ${compare_scenario}:"
            
            for runtime in "${RUNTIMES[@]}"; do
                local base_val=$(get_mean "$runtime" "$base_scenario" "$metric_path")
                local comp_val=$(get_mean "$runtime" "$compare_scenario" "$metric_path")
                
                if [ "$base_val" != "N/A" ] && [ "$comp_val" != "N/A" ]; then
                    local improvement
                    if [ "$lower_is_better" = "true" ]; then
                        improvement=$(calculate_improvement "$base_val" "$comp_val")
                    else
                        improvement=$(calculate_improvement "$comp_val" "$base_val")
                    fi
                    printf "    %-25s: %s\n" "$runtime" "$improvement"
                fi
            done
        done
    fi
    
    # If we have multiple runtimes, show runtime comparisons
    if [ ${#RUNTIMES[@]} -gt 1 ]; then
        echo ""
        echo "Runtime Comparisons (for each scenario):"
        
        for scenario in "${SCENARIOS[@]}"; do
            echo ""
            echo "  Scenario: ${scenario}"
            
            # Find best and worst
            local best_runtime=""
            local best_value=""
            local worst_runtime=""
            local worst_value=""
            
            for runtime in "${RUNTIMES[@]}"; do
                local value=$(get_mean "$runtime" "$scenario" "$metric_path")
                if [ "$value" != "N/A" ]; then
                    if [ -z "$best_value" ]; then
                        best_value="$value"
                        best_runtime="$runtime"
                        worst_value="$value"
                        worst_runtime="$runtime"
                    else
                        if [ "$lower_is_better" = "true" ]; then
                            if (( $(awk "BEGIN {print ($value < $best_value)}") )); then
                                best_value="$value"
                                best_runtime="$runtime"
                            fi
                            if (( $(awk "BEGIN {print ($value > $worst_value)}") )); then
                                worst_value="$value"
                                worst_runtime="$runtime"
                            fi
                        else
                            if (( $(awk "BEGIN {print ($value > $best_value)}") )); then
                                best_value="$value"
                                best_runtime="$runtime"
                            fi
                            if (( $(awk "BEGIN {print ($value < $worst_value)}") )); then
                                worst_value="$value"
                                worst_runtime="$runtime"
                            fi
                        fi
                    fi
                fi
            done
            
            if [ -n "$best_runtime" ]; then
                echo "    Best:  $best_runtime = $best_value"
                echo "    Worst: $worst_runtime = $worst_value"
                
                if [ "$best_runtime" != "$worst_runtime" ]; then
                    local diff
                    if [ "$lower_is_better" = "true" ]; then
                        diff=$(calculate_improvement "$worst_value" "$best_value")
                    else
                        diff=$(calculate_improvement "$best_value" "$worst_value")
                    fi
                    echo "    Difference: $diff"
                fi
            fi
        done
    fi
}

# Main execution
log_info "Analyzing results from: $RESULTS_DIR"

# Find all runtimes and scenarios
RUNTIMES=()
SCENARIOS=()

for file in "$RESULTS_FILES_DIR"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file" .json)
        # Extract runtime and scenario from filename: runtime-scenario-iteration.json
        # Remove the iteration number (last part after last dash)
        base_without_iteration=$(echo "$basename" | sed 's/-[^-]*$//')
        # Now extract runtime (everything except last part) and scenario (last part)
        runtime=$(echo "$base_without_iteration" | sed 's/-[^-]*$//')
        scenario=$(echo "$base_without_iteration" | sed 's/^.*-//')
        
        if [[ ! " ${RUNTIMES[@]} " =~ " ${runtime} " ]]; then
            RUNTIMES+=("$runtime")
        fi
        if [[ ! " ${SCENARIOS[@]} " =~ " ${scenario} " ]]; then
            SCENARIOS+=("$scenario")
        fi
    fi
done

log_info "Found runtimes: ${RUNTIMES[@]}"
log_info "Found scenarios: ${SCENARIOS[@]}"

echo ""
echo "================================================================================"
echo "COMPREHENSIVE PERFORMANCE COMPARISON"
echo "================================================================================"
echo "Runtimes: ${RUNTIMES[@]}"
echo "Scenarios: ${SCENARIOS[@]}"
echo "================================================================================"

# Print comparison matrices for each metric
print_metric_matrix "Startup Time (ms)" ".tests.startup.startup_time_ms" "true"
print_metric_matrix "Memory Usage (MB)" ".tests.memory.rss_mb" "true"
print_metric_matrix "Throughput (req/s)" ".tests.load_test.requests_per_sec" "false"
print_metric_matrix "Latency Mean (ms)" ".tests.load_test.latency_mean_ms" "true"
print_metric_matrix "Latency P50 (ms)" ".tests.load_test.latency_p50_ms" "true"
print_metric_matrix "Latency P90 (ms)" ".tests.load_test.latency_p90_ms" "true"
print_metric_matrix "Latency P99 (ms)" ".tests.load_test.latency_p99_ms" "true"

echo ""
echo "================================================================================"
log_info "Comparison completed"
echo "================================================================================"

# Made with Bob