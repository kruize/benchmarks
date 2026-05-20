#!/bin/bash

# ============================================================================
# Analyze Session - Within-Session Variability Analysis
# ============================================================================
# This script analyzes variability and consistency within a single session,
# measuring how stable performance is across multiple iterations.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
SESSION_DIR=""
OUTPUT_FILE=""
FORMAT="text"  # text or json

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $@"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $@"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $@"
}

usage() {
    cat << EOF
Usage: $0 --session-dir <directory> [options]

Analyze within-session variability to measure performance consistency
across multiple iterations of the same test configuration.

Required:
  --session-dir <dir>      Path to session directory

Optional:
  --output <file>          Output file for analysis results
  --format <type>          Output format: text or json (default: text)
  --help                   Show this help message

Examples:
  # Analyze variability in a session
  $0 --session-dir ./variable-load-results/session-baseline

  # Generate JSON output
  $0 --session-dir ./variable-load-results/session-baseline \\
     --format json --output variability-analysis.json

Metrics Analyzed:
  - Coefficient of Variation (CV%): (stddev/mean) × 100 (lower = more consistent)
  - Range: max - min (absolute variability)
  - Stability Score: 100 - CV (higher = more stable, 0-100 scale)

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
        --format)
            FORMAT="$2"
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
    log_error "--session-dir is required"
    usage
fi

if [ ! -d "$SESSION_DIR" ]; then
    log_error "Session directory not found: $SESSION_DIR"
    exit 1
fi

# Check for aggregated file
AGG_FILE="${SESSION_DIR}/aggregated.json"

if [ ! -f "$AGG_FILE" ]; then
    log_error "Aggregated file not found: $AGG_FILE"
    log_error "Run aggregate-session.sh first: ./aggregate-session.sh --session-dir $SESSION_DIR"
    exit 1
fi

log_info "========================================="
log_info "Analyzing Session Variability"
log_info "========================================="
log_info "Session Dir: $SESSION_DIR"
log_info "Format: $FORMAT"
if [ -n "$OUTPUT_FILE" ]; then
    log_info "Output: $OUTPUT_FILE"
fi
log_info ""

# Use Python for analysis
export SESSION_DIR
export OUTPUT_FILE
export FORMAT

python3 - "$SESSION_DIR" "$OUTPUT_FILE" "$FORMAT" << 'PYTHON_SCRIPT'
import json
import sys
import os
import glob
import statistics

def calculate_cv(mean, stddev):
    """Calculate Coefficient of Variation (CV)"""
    if mean is None or stddev is None or mean == 0:
        return None
    return round((stddev / mean) * 100, 2)

def calculate_stability_score(cv):
    """Calculate stability score (0-100, higher is better)"""
    if cv is None:
        return None
    return max(0, round(100 - cv, 2))

def parse_memory_value(mem_str):
    """Convert memory string (e.g., '512Mi', '1Gi') to MB"""
    if not mem_str:
        return None
    mem_str = str(mem_str).strip()
    if mem_str.endswith('Mi'):
        return float(mem_str[:-2])
    elif mem_str.endswith('Gi'):
        return float(mem_str[:-2]) * 1024
    elif mem_str.endswith('Ki'):
        return float(mem_str[:-2]) / 1024
    else:
        try:
            return float(mem_str) / (1024 * 1024)
        except:
            return None

def analyze_startup_metrics(session_dir):
    """Analyze startup metrics variability"""
    startup_files = glob.glob(os.path.join(session_dir, '*-startup.json'))
    
    if not startup_files:
        return None
    
    startup_times = []
    memory_usages = []
    cpu_usages = []
    
    for file_path in startup_files:
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            
            if data.get('startup_time_seconds'):
                startup_times.append(data['startup_time_seconds'])
            
            mem_usage = data.get('memory', {}).get('current_usage', '')
            if mem_usage:
                mem_mb = parse_memory_value(mem_usage)
                if mem_mb:
                    memory_usages.append(mem_mb)
            
            cpu_usage = data.get('cpu', {}).get('current_usage', '')
            if cpu_usage and cpu_usage.endswith('m'):
                try:
                    cpu_usages.append(float(cpu_usage[:-1]))
                except:
                    pass
        except Exception as e:
            print(f"Warning: Could not parse {file_path}: {e}", file=sys.stderr)
            continue
    
    result = {
        'iterations': len(startup_files)
    }
    
    if startup_times and len(startup_times) > 1:
        mean_time = statistics.mean(startup_times)
        stddev_time = statistics.stdev(startup_times)
        cv_time = calculate_cv(mean_time, stddev_time)
        result['startup_time'] = {
            'mean': round(mean_time, 2),
            'stddev': round(stddev_time, 2),
            'cv': cv_time,
            'min': min(startup_times),
            'max': max(startup_times),
            'range': round(max(startup_times) - min(startup_times), 2),
            'stability_score': calculate_stability_score(cv_time)
        }
    
    if memory_usages and len(memory_usages) > 1:
        mean_mem = statistics.mean(memory_usages)
        stddev_mem = statistics.stdev(memory_usages)
        cv_mem = calculate_cv(mean_mem, stddev_mem)
        result['memory_mb'] = {
            'mean': round(mean_mem, 2),
            'stddev': round(stddev_mem, 2),
            'cv': cv_mem,
            'min': round(min(memory_usages), 2),
            'max': round(max(memory_usages), 2),
            'range': round(max(memory_usages) - min(memory_usages), 2),
            'stability_score': calculate_stability_score(cv_mem)
        }
    
    if cpu_usages and len(cpu_usages) > 1:
        mean_cpu = statistics.mean(cpu_usages)
        stddev_cpu = statistics.stdev(cpu_usages)
        cv_cpu = calculate_cv(mean_cpu, stddev_cpu)
        result['cpu_millicores'] = {
            'mean': round(mean_cpu, 2),
            'stddev': round(stddev_cpu, 2),
            'cv': cv_cpu,
            'min': round(min(cpu_usages), 2),
            'max': round(max(cpu_usages), 2),
            'range': round(max(cpu_usages) - min(cpu_usages), 2),
            'stability_score': calculate_stability_score(cv_cpu)
        }
    
    return result if len(result) > 1 else None

# Read command line arguments
if len(sys.argv) < 4:
    print("ERROR: Missing required arguments", file=sys.stderr)
    sys.exit(1)

session_dir = sys.argv[1]
output_file = sys.argv[2] if sys.argv[2] else ''
output_format = sys.argv[3] if len(sys.argv) > 3 else 'text'

agg_file = os.path.join(session_dir, 'aggregated.json')

# Load aggregated data
with open(agg_file, 'r') as f:
    data = json.load(f)

# Extract metadata
session_id = data.get('session_id', 'unknown')
runtime = data.get('runtime', 'unknown')
total_iterations = data.get('total_iterations', 0)

# Analyze startup metrics
startup_analysis = analyze_startup_metrics(session_dir)

# Analyze each phase
phase_analyses = []

for phase in data.get('phases', []):
    phase_name = phase.get('phase_name')
    
    # Calculate CVs for key metrics (using actual field names from aggregated.json)
    throughput_cv = calculate_cv(
        phase['requests_per_sec']['mean'],
        phase['requests_per_sec']['stddev']
    )
    mean_latency_cv = calculate_cv(
        phase['latency_mean_ms']['mean'],
        phase['latency_mean_ms']['stddev']
    )
    p99_latency_cv = calculate_cv(
        phase['latency_p99_ms']['mean'],
        phase['latency_p99_ms']['stddev']
    )
    
    # Calculate stability scores
    throughput_stability = calculate_stability_score(throughput_cv)
    latency_stability = calculate_stability_score(mean_latency_cv)
    
    # Overall stability (average of throughput and latency)
    if throughput_stability is not None and latency_stability is not None:
        overall_stability = round((throughput_stability + latency_stability) / 2, 2)
    else:
        overall_stability = None
    
    analysis = {
        'phase_name': phase_name,
        'threads': phase.get('threads'),
        'connections': phase.get('connections'),
        'iterations': phase.get('iterations', total_iterations),
        'requests_per_sec': {
            'mean': phase['requests_per_sec']['mean'],
            'stddev': phase['requests_per_sec']['stddev'],
            'cv': throughput_cv,
            'range': round(phase['requests_per_sec']['max'] - phase['requests_per_sec']['min'], 2),
            'stability_score': throughput_stability
        },
        'latency_mean_ms': {
            'mean': phase['latency_mean_ms']['mean'],
            'stddev': phase['latency_mean_ms']['stddev'],
            'cv': mean_latency_cv,
            'range': round(phase['latency_mean_ms']['max'] - phase['latency_mean_ms']['min'], 2),
            'stability_score': latency_stability
        },
        'latency_p99_ms': {
            'mean': phase['latency_p99_ms']['mean'],
            'stddev': phase['latency_p99_ms']['stddev'],
            'cv': p99_latency_cv,
            'range': round(phase['latency_p99_ms']['max'] - phase['latency_p99_ms']['min'], 2)
        },
        'overall_stability_score': overall_stability
    }
    
    phase_analyses.append(analysis)

# Generate output
if output_format == 'json':
    output = {
        'session_id': session_id,
        'runtime': runtime,
        'total_iterations': total_iterations,
        'startup_analysis': startup_analysis,
        'phase_analyses': phase_analyses
    }
    
    if output_file:
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)
        print(f"JSON analysis written to {output_file}")
    else:
        print(json.dumps(output, indent=2))

else:  # text format
    output_lines = []
    output_lines.append("=" * 100)
    output_lines.append(f"SESSION VARIABILITY ANALYSIS: {session_id}")
    output_lines.append("=" * 100)
    output_lines.append(f"Runtime: {runtime}")
    output_lines.append(f"Total Iterations: {total_iterations}")
    output_lines.append("")
    
    # Add startup metrics analysis if available
    if startup_analysis and startup_analysis.get('iterations', 0) > 0:
        output_lines.append("=" * 100)
        output_lines.append("STARTUP METRICS VARIABILITY")
        output_lines.append("=" * 100)
        output_lines.append(f"Iterations Analyzed: {startup_analysis['iterations']}")
        output_lines.append("")
        output_lines.append(f"{'Metric':<25} {'Mean':<12} {'StdDev':<12} {'CV%':<10} {'Range':<12} {'Stability':<10}")
        output_lines.append("-" * 85)
        
        if 'startup_time' in startup_analysis:
            st = startup_analysis['startup_time']
            output_lines.append(f"{'Startup Time (sec)':<25} "
                              f"{st['mean']:<12.2f} "
                              f"{st['stddev']:<12.2f} "
                              f"{st['cv']:<10.2f} "
                              f"{st['range']:<12.2f} "
                              f"{st['stability_score']:<10.2f}")
        
        if 'memory_mb' in startup_analysis:
            mem = startup_analysis['memory_mb']
            output_lines.append(f"{'Memory (MB)':<25} "
                              f"{mem['mean']:<12.2f} "
                              f"{mem['stddev']:<12.2f} "
                              f"{mem['cv']:<10.2f} "
                              f"{mem['range']:<12.2f} "
                              f"{mem['stability_score']:<10.2f}")
        
        if 'cpu_millicores' in startup_analysis:
            cpu = startup_analysis['cpu_millicores']
            output_lines.append(f"{'CPU (millicores)':<25} "
                              f"{cpu['mean']:<12.2f} "
                              f"{cpu['stddev']:<12.2f} "
                              f"{cpu['cv']:<10.2f} "
                              f"{cpu['range']:<12.2f} "
                              f"{cpu['stability_score']:<10.2f}")
        
        output_lines.append("")
        output_lines.append("Startup Metrics Interpretation:")
        output_lines.append("  - CV% < 5%: Very consistent startup behavior")
        output_lines.append("  - CV% 5-10%: Acceptable variability")
        output_lines.append("  - CV% > 10%: High variability, investigate environmental factors")
        output_lines.append("")
    
    for analysis in phase_analyses:
        output_lines.append("-" * 100)
        output_lines.append(f"PHASE: {analysis['phase_name']}")
        output_lines.append(f"Configuration: {analysis['threads']} threads, {analysis['connections']} connections")
        output_lines.append(f"Iterations: {analysis['iterations']}")
        output_lines.append(f"Overall Stability Score: {analysis['overall_stability_score']:.2f}/100")
        output_lines.append("-" * 100)
        output_lines.append("")
        
        # Throughput
        output_lines.append("THROUGHPUT (requests/sec):")
        output_lines.append(f"  Mean:        {analysis['requests_per_sec']['mean']:.2f} req/s")
        output_lines.append(f"  Std Dev:     {analysis['requests_per_sec']['stddev']:.2f} req/s")
        output_lines.append(f"  CV:          {analysis['requests_per_sec']['cv']:.2f}%")
        output_lines.append(f"  Range:       {analysis['requests_per_sec']['range']:.2f} req/s")
        output_lines.append(f"  Stability:   {analysis['requests_per_sec']['stability_score']:.2f}/100")
        output_lines.append("")
        
        # Mean Latency
        output_lines.append("MEAN LATENCY (ms):")
        output_lines.append(f"  Mean:        {analysis['latency_mean_ms']['mean']:.2f} ms")
        output_lines.append(f"  Std Dev:     {analysis['latency_mean_ms']['stddev']:.2f} ms")
        output_lines.append(f"  CV:          {analysis['latency_mean_ms']['cv']:.2f}%")
        output_lines.append(f"  Range:       {analysis['latency_mean_ms']['range']:.2f} ms")
        output_lines.append(f"  Stability:   {analysis['latency_mean_ms']['stability_score']:.2f}/100")
        output_lines.append("")
        
        # P99 Latency
        output_lines.append("P99 LATENCY (ms):")
        output_lines.append(f"  Mean:        {analysis['latency_p99_ms']['mean']:.2f} ms")
        output_lines.append(f"  Std Dev:     {analysis['latency_p99_ms']['stddev']:.2f} ms")
        output_lines.append(f"  CV:          {analysis['latency_p99_ms']['cv']:.2f}%")
        output_lines.append(f"  Range:       {analysis['latency_p99_ms']['range']:.2f} ms")
        output_lines.append("")
    
    output_lines.append("=" * 100)
    output_lines.append("SUMMARY")
    output_lines.append("=" * 100)
    
    # Calculate overall session stability
    stability_scores = [a['overall_stability_score'] for a in phase_analyses if a['overall_stability_score'] is not None]
    if stability_scores:
        avg_stability = sum(stability_scores) / len(stability_scores)
        output_lines.append(f"Average Session Stability Score: {avg_stability:.2f}/100")
    
    output_lines.append("=" * 100)
    
    output_text = "\n".join(output_lines)
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(output_text)
        print(f"Text analysis written to {output_file}")
    else:
        print(output_text)

PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    log_info ""
    log_info "Analysis complete!"
else
    log_error "Analysis failed"
    exit 1
fi

# Made with Bob
