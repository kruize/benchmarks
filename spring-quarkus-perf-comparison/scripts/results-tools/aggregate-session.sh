#!/bin/bash

# ============================================================================
# Aggregate Session Results - Phase-Level Statistics
# ============================================================================
# This script aggregates metrics across multiple iterations within a session,
# calculating mean, median, and standard deviation for each phase.
#
# Output: Creates aggregated JSON files compatible with existing comparison tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "${SCRIPT_DIR}/../common-utils.sh"

# Default values
SESSION_DIR=""
OUTPUT_FILE=""

usage() {
    cat << EOF
Usage: $0 --session-dir <directory> [options]

Aggregate metrics across multiple iterations within a session.
Calculates mean, median, and standard deviation for each phase.

Required:
  --session-dir <dir>      Path to session directory (e.g., ./variable-load-results/session-baseline)

Optional:
  --output <file>          Output aggregated JSON file (default: <session-dir>/aggregated.json)
  --help                   Show this help message

Examples:
  # Aggregate all iterations in a session
  $0 --session-dir ./variable-load-results/session-baseline

  # Specify custom output file
  $0 --session-dir ./variable-load-results/session-baseline --output baseline-stats.json

Output Format:
  The aggregated JSON contains mean, median, stddev, min, max for each metric
  across all iterations, organized by phase. This format is compatible with
  existing comparison and reporting tools.

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --session-dir)
            SESSION_DIR="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
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
if [ -z "$SESSION_DIR" ]; then
    log_error_color "--session-dir is required"
    usage
fi

if ! validate_directory "$SESSION_DIR" "Session directory"; then
    exit 1
fi

# Set default output file
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${SESSION_DIR}/aggregated.json"
fi

log_info_color "========================================="
log_info_color "Aggregating Session Results"
log_info_color "========================================="
log_info_color "Session Dir: $SESSION_DIR"
log_info_color "Output File: $OUTPUT_FILE"
log_info_color ""

# Find consolidated iteration JSON files (not phase-specific files)
# Pattern: *-{scenario}-iter{N}.json (e.g., quarkus3-jvm-ootb-iter1.json)
ITERATION_FILES=($(find "$SESSION_DIR" -maxdepth 1 -name "*-iter[0-9]*.json" ! -name "*_phase*" | sort))

if [ ${#ITERATION_FILES[@]} -eq 0 ]; then
    log_error_color "No iteration files found in $SESSION_DIR"
    log_error_color "Expected files matching pattern: *-iter*.json"
    exit 1
fi

log_info_color "Found ${#ITERATION_FILES[@]} iteration files:"
for file in "${ITERATION_FILES[@]}"; do
    log_info_color "  - $(basename $file)"
done
log_info_color ""

# Use Python for statistical calculations
log_info_color "Calculating statistics..."

python3 - "$SESSION_DIR" "$OUTPUT_FILE" << 'PYTHON_SCRIPT'
import json
import sys
import statistics
from pathlib import Path

def safe_float(value):
    """Convert value to float, handling None and invalid values"""
    if value is None:
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None

def calculate_stats(values):
    """Calculate mean, median, stddev, min, max for a list of values"""
    # Filter out None values
    valid_values = [v for v in values if v is not None]
    
    if not valid_values:
        return {
            "mean": None,
            "median": None,
            "stddev": None,
            "min": None,
            "max": None,
            "count": 0
        }
    
    return {
        "mean": round(statistics.mean(valid_values), 2),
        "median": round(statistics.median(valid_values), 2),
        "stddev": round(statistics.stdev(valid_values), 2) if len(valid_values) > 1 else 0,
        "min": round(min(valid_values), 2),
        "max": round(max(valid_values), 2),
        "count": len(valid_values)
    }

# Read arguments from command line
if len(sys.argv) < 3:
    print("ERROR: Missing required arguments", file=sys.stderr)
    sys.exit(1)

session_dir = sys.argv[1]
output_file = sys.argv[2]

# Find consolidated iteration files (exclude phase-specific files)
all_iter_files = sorted(Path(session_dir).glob('*-iter[0-9]*.json'))
iteration_files = [f for f in all_iter_files if '_phase' not in f.name]

if not iteration_files:
    print(f"ERROR: No iteration files found", file=sys.stderr)
    sys.exit(1)

# Load all iterations
iterations_data = []
for file_path in iteration_files:
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
            iterations_data.append(data)
    except Exception as e:
        print(f"WARNING: Failed to load {file_path}: {e}", file=sys.stderr)

if not iterations_data:
    print("ERROR: No valid iteration data loaded", file=sys.stderr)
    sys.exit(1)

# Extract metadata from first iteration
first_iter = iterations_data[0]
runtime = first_iter.get('runtime', 'unknown')
scenario = first_iter.get('scenario', 'unknown')
test_type = first_iter.get('test_type', 'multi-phase-variable-load')
duration_mode = first_iter.get('duration_mode', 'unknown')
session_id = first_iter.get('session_id', 'unknown')

# Aggregate phase data
phase_aggregates = {}

for iteration in iterations_data:
    phases = iteration.get('phases', [])
    
    for phase in phases:
        phase_name = phase.get('phase_name', 'unknown')
        config = phase.get('configuration', {})
        results = phase.get('results', {})
        
        if phase_name not in phase_aggregates:
            phase_aggregates[phase_name] = {
                'throughput': [],
                'mean_latency': [],
                'p50_latency': [],
                'p90_latency': [],
                'p99_latency': [],
                'errors': [],
                'threads': config.get('threads'),
                'connections': config.get('connections'),
                'duration': config.get('duration')
            }
        
        # Collect values from results section
        phase_aggregates[phase_name]['throughput'].append(safe_float(results.get('requests_per_sec')))
        phase_aggregates[phase_name]['mean_latency'].append(safe_float(results.get('latency_mean_ms')))
        phase_aggregates[phase_name]['p50_latency'].append(safe_float(results.get('latency_p50_ms')))
        phase_aggregates[phase_name]['p90_latency'].append(safe_float(results.get('latency_p90_ms')))
        phase_aggregates[phase_name]['p99_latency'].append(safe_float(results.get('latency_p99_ms')))
        phase_aggregates[phase_name]['errors'].append(safe_float(results.get('errors', 0)))

# Calculate statistics for each phase
aggregated_phases = []

for phase_name, data in phase_aggregates.items():
    phase_stats = {
        'phase_name': phase_name,
        'threads': data['threads'],
        'connections': data['connections'],
        'duration': data['duration'],
        'iterations': len(iterations_data),
        'requests_per_sec': calculate_stats(data['throughput']),
        'latency_mean_ms': calculate_stats(data['mean_latency']),
        'latency_p50_ms': calculate_stats(data['p50_latency']),
        'latency_p90_ms': calculate_stats(data['p90_latency']),
        'latency_p99_ms': calculate_stats(data['p99_latency']),
        'errors': calculate_stats(data['errors'])
    }
    aggregated_phases.append(phase_stats)

# Create output JSON
output = {
    'runtime': runtime,
    'scenario': scenario,
    'test_type': 'aggregated-multi-phase',
    'duration_mode': duration_mode,
    'session_id': session_id,
    'total_iterations': len(iterations_data),
    'aggregation_timestamp': first_iter.get('timestamp', 'unknown'),
    'phases': aggregated_phases
}

# Write output
with open(output_file, 'w') as f:
    json.dump(output, f, indent=2)

print(f"SUCCESS: Aggregated data written to {output_file}")

PYTHON_SCRIPT

# Check if Python script succeeded
if [ $? -eq 0 ]; then
    log_info_color ""
    log_info_color "========================================="
    log_info_color "Aggregation Complete!"
    log_info_color "========================================="
    log_info_color "Output: $OUTPUT_FILE"
    log_info_color ""
    log_info_color "You can now use this aggregated file with:"
    log_info_color "  - compare-all.sh for comparison"
    log_info_color "  - generate-report.sh for HTML reports"
else
    log_error_color "Aggregation failed"
    exit 1
fi

# Made with Bob
