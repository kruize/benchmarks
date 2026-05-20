#!/bin/bash

# ============================================================================
# Compare Sessions - Cross-Session Phase-Level Comparison
# ============================================================================
# This script compares two sessions (e.g., OOTB vs Tuned) at the phase level,
# showing performance differences for each phase.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
SESSION_A=""
SESSION_B=""
SESSION_A_NAME=""
SESSION_B_NAME=""
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
Usage: $0 --session-a <dir> --session-b <dir> [options]

Compare two sessions at the phase level, showing performance differences.
Sessions should contain aggregated.json files (use aggregate-session.sh first).

Required:
  --session-a <dir>        First session directory (e.g., baseline/OOTB)
  --session-b <dir>        Second session directory (e.g., optimized/Tuned)

Optional:
  --session-a-name <name>  Display name for session A (default: from session_id in aggregated.json)
  --session-b-name <name>  Display name for session B (default: from session_id in aggregated.json)
  --output <file>          Output file for comparison results
  --format <type>          Output format: text or json (default: text)
  --help                   Show this help message

Examples:
  # Compare OOTB vs Tuned sessions
  $0 --session-a ./variable-load-results/session-baseline \\
     --session-b ./variable-load-results/session-optimized

  # Generate JSON output
  $0 --session-a ./variable-load-results/session-baseline \\
     --session-b ./variable-load-results/session-optimized \\
     --format json --output comparison.json

Workflow:
  1. Run tests with session-id for both configurations:
     ./run-variable-load-multi-phase.sh --runtime quarkus3-jvm --scenario ootb --session-id baseline
     ./run-variable-load-multi-phase.sh --runtime quarkus3-jvm --scenario tuned --session-id optimized
  
  2. Aggregate each session:
     ./aggregate-session.sh --session-dir ./variable-load-results/session-baseline
     ./aggregate-session.sh --session-dir ./variable-load-results/session-optimized
  
  3. Compare sessions:
     $0 --session-a ./variable-load-results/session-baseline \\
        --session-b ./variable-load-results/session-optimized

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --session-a)
            SESSION_A="$2"
            shift 2
            ;;
        --session-b)
            SESSION_B="$2"
            shift 2
            ;;
        --session-a-name)
            SESSION_A_NAME="$2"
            shift 2
            ;;
        --session-b-name)
            SESSION_B_NAME="$2"
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
if [ -z "$SESSION_A" ] || [ -z "$SESSION_B" ]; then
    log_error "Both --session-a and --session-b are required"
    usage
fi

if [ ! -d "$SESSION_A" ]; then
    log_error "Session A directory not found: $SESSION_A"
    exit 1
fi

if [ ! -d "$SESSION_B" ]; then
    log_error "Session B directory not found: $SESSION_B"
    exit 1
fi

# Check for aggregated files
AGG_A="${SESSION_A}/aggregated.json"
AGG_B="${SESSION_B}/aggregated.json"

if [ ! -f "$AGG_A" ]; then
    log_error "Aggregated file not found: $AGG_A"
    log_error "Run aggregate-session.sh first: ./aggregate-session.sh --session-dir $SESSION_A"
    exit 1
fi

if [ ! -f "$AGG_B" ]; then
    log_error "Aggregated file not found: $AGG_B"
    log_error "Run aggregate-session.sh first: ./aggregate-session.sh --session-dir $SESSION_B"
    exit 1
fi

log_info "========================================="
log_info "Comparing Sessions"
log_info "========================================="
log_info "Session A: $SESSION_A"
log_info "Session B: $SESSION_B"
log_info "Format: $FORMAT"
if [ -n "$OUTPUT_FILE" ]; then
    log_info "Output: $OUTPUT_FILE"
fi
log_info ""

# Use Python for comparison
export SESSION_A
export SESSION_B
export SESSION_A_NAME
export SESSION_B_NAME
export OUTPUT_FILE
export FORMAT

python3 - "$SESSION_A" "$SESSION_B" "$SESSION_A_NAME" "$SESSION_B_NAME" "$OUTPUT_FILE" "$FORMAT" << 'PYTHON_SCRIPT'
import json
import sys
import os
import glob

def calculate_improvement(baseline, optimized):
    """Calculate percentage improvement (positive = better)"""
    if baseline is None or optimized is None or baseline == 0:
        return None
    return round(((optimized - baseline) / baseline) * 100, 2)

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
        # Assume bytes
        try:
            return float(mem_str) / (1024 * 1024)
        except:
            return None

def load_startup_metrics(session_dir):
    """Load and aggregate startup metrics from all iterations"""
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
            
            # CPU usage is typically like "10m" (millicores)
            cpu_usage = data.get('cpu', {}).get('current_usage', '')
            if cpu_usage and cpu_usage.endswith('m'):
                try:
                    cpu_usages.append(float(cpu_usage[:-1]))
                except:
                    pass
        except Exception as e:
            print(f"Warning: Could not parse {file_path}: {e}", file=sys.stderr)
            continue
    
    if not startup_times and not memory_usages:
        return None
    
    result = {
        'iterations': len(startup_files)
    }
    
    if startup_times:
        result['startup_time'] = {
            'mean': round(sum(startup_times) / len(startup_times), 2),
            'min': min(startup_times),
            'max': max(startup_times)
        }
    
    if memory_usages:
        result['memory_mb'] = {
            'mean': round(sum(memory_usages) / len(memory_usages), 2),
            'min': round(min(memory_usages), 2),
            'max': round(max(memory_usages), 2)
        }
    
    if cpu_usages:
        result['cpu_millicores'] = {
            'mean': round(sum(cpu_usages) / len(cpu_usages), 2),
            'min': round(min(cpu_usages), 2),
            'max': round(max(cpu_usages), 2)
        }
    
    return result

def format_improvement(value, metric_type='throughput'):
    """Format improvement with color coding"""
    if value is None:
        return "N/A"
    
    # For throughput: higher is better
    # For latency/errors: lower is better
    if metric_type in ['throughput']:
        if value > 0:
            return f"+{value}% ✓"
        elif value < 0:
            return f"{value}% ✗"
    else:  # latency, errors
        if value < 0:
            return f"{value}% ✓"
        elif value > 0:
            return f"+{value}% ✗"
    
    return f"{value}%"

# Read command line arguments
if len(sys.argv) < 7:
    print("ERROR: Missing required arguments", file=sys.stderr)
    sys.exit(1)

session_a_dir = sys.argv[1]
session_b_dir = sys.argv[2]
session_a_name_override = sys.argv[3] if sys.argv[3] else ''
session_b_name_override = sys.argv[4] if sys.argv[4] else ''
output_file = sys.argv[5] if sys.argv[5] else ''
output_format = sys.argv[6] if len(sys.argv) > 6 else 'text'

agg_a_path = os.path.join(session_a_dir, 'aggregated.json')
agg_b_path = os.path.join(session_b_dir, 'aggregated.json')

# Load aggregated data
with open(agg_a_path, 'r') as f:
    data_a = json.load(f)

with open(agg_b_path, 'r') as f:
    data_b = json.load(f)

# Extract metadata
session_a_id = session_a_name_override if session_a_name_override else data_a.get('session_id', 'A')
session_b_id = session_b_name_override if session_b_name_override else data_b.get('session_id', 'B')
runtime = data_a.get('runtime', 'unknown')

# Load startup metrics
startup_a = load_startup_metrics(session_a_dir)
startup_b = load_startup_metrics(session_b_dir)

# Create phase comparison
phase_comparisons = []

phases_a = {p['phase_name']: p for p in data_a.get('phases', [])}
phases_b = {p['phase_name']: p for p in data_b.get('phases', [])}

for phase_name in phases_a.keys():
    if phase_name not in phases_b:
        continue
    
    phase_a = phases_a[phase_name]
    phase_b = phases_b[phase_name]
    
    comparison = {
        'phase_name': phase_name,
        'threads': phase_a.get('threads'),
        'connections': phase_a.get('connections'),
        session_a_id: {
            'requests_per_sec': phase_a['requests_per_sec']['mean'],
            'latency_mean_ms': phase_a['latency_mean_ms']['mean'],
            'latency_p99_ms': phase_a['latency_p99_ms']['mean'],
            'errors': phase_a['errors']['mean']
        },
        session_b_id: {
            'requests_per_sec': phase_b['requests_per_sec']['mean'],
            'latency_mean_ms': phase_b['latency_mean_ms']['mean'],
            'latency_p99_ms': phase_b['latency_p99_ms']['mean'],
            'errors': phase_b['errors']['mean']
        },
        'improvement': {
            'requests_per_sec': calculate_improvement(
                phase_a['requests_per_sec']['mean'],
                phase_b['requests_per_sec']['mean']
            ),
            'latency_mean_ms': calculate_improvement(
                phase_a['latency_mean_ms']['mean'],
                phase_b['latency_mean_ms']['mean']
            ),
            'latency_p99_ms': calculate_improvement(
                phase_a['latency_p99_ms']['mean'],
                phase_b['latency_p99_ms']['mean']
            ),
            'errors': calculate_improvement(
                phase_a['errors']['mean'],
                phase_b['errors']['mean']
            )
        }
    }
    
    phase_comparisons.append(comparison)

# Generate output
if output_format == 'json':
    output = {
        'runtime': runtime,
        session_a_id: {
            'iterations': data_a.get('total_iterations'),
            'startup_metrics': startup_a
        },
        session_b_id: {
            'iterations': data_b.get('total_iterations'),
            'startup_metrics': startup_b
        },
        'phase_comparisons': phase_comparisons
    }
    
    # Add startup comparison if both sessions have startup metrics
    if startup_a and startup_b:
        startup_comparison = {}
        
        if 'startup_time' in startup_a and 'startup_time' in startup_b:
            startup_comparison['startup_time'] = {
                session_a_id: startup_a['startup_time']['mean'],
                session_b_id: startup_b['startup_time']['mean'],
                'improvement_pct': calculate_improvement(
                    startup_a['startup_time']['mean'],
                    startup_b['startup_time']['mean']
                )
            }
        
        if 'memory_mb' in startup_a and 'memory_mb' in startup_b:
            startup_comparison['memory_mb'] = {
                session_a_id: startup_a['memory_mb']['mean'],
                session_b_id: startup_b['memory_mb']['mean'],
                'improvement_pct': calculate_improvement(
                    startup_a['memory_mb']['mean'],
                    startup_b['memory_mb']['mean']
                )
            }
        
        if 'cpu_millicores' in startup_a and 'cpu_millicores' in startup_b:
            startup_comparison['cpu_millicores'] = {
                session_a_id: startup_a['cpu_millicores']['mean'],
                session_b_id: startup_b['cpu_millicores']['mean'],
                'improvement_pct': calculate_improvement(
                    startup_a['cpu_millicores']['mean'],
                    startup_b['cpu_millicores']['mean']
                )
            }
        
        output['startup_comparison'] = startup_comparison
    
    if output_file:
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)
        print(f"JSON comparison written to {output_file}")
    else:
        print(json.dumps(output, indent=2))

else:  # text format
    output_lines = []
    output_lines.append("=" * 100)
    output_lines.append(f"SESSION COMPARISON: {session_a_id} vs {session_b_id}")
    output_lines.append("=" * 100)
    output_lines.append(f"Runtime: {runtime}")
    output_lines.append(f"Session A ({session_a_id}): {data_a.get('total_iterations')} iterations")
    output_lines.append(f"Session B ({session_b_id}): {data_b.get('total_iterations')} iterations")
    output_lines.append("")
    
    # Add startup metrics comparison if available
    if startup_a and startup_b:
        output_lines.append("=" * 100)
        output_lines.append("STARTUP METRICS COMPARISON")
        output_lines.append("=" * 100)
        output_lines.append("")
        output_lines.append(f"{'Metric':<25} {session_a_id:<20} {session_b_id:<20} {'Improvement':<20}")
        output_lines.append("-" * 85)
        
        # Startup Time
        if 'startup_time' in startup_a and 'startup_time' in startup_b:
            time_a = startup_a['startup_time']['mean']
            time_b = startup_b['startup_time']['mean']
            improvement = calculate_improvement(time_a, time_b)
            output_lines.append(f"{'Startup Time (seconds)':<25} "
                              f"{time_a:<20.2f} "
                              f"{time_b:<20.2f} "
                              f"{format_improvement(improvement, 'latency'):<20}")
        
        # Memory Usage
        if 'memory_mb' in startup_a and 'memory_mb' in startup_b:
            mem_a = startup_a['memory_mb']['mean']
            mem_b = startup_b['memory_mb']['mean']
            improvement = calculate_improvement(mem_a, mem_b)
            output_lines.append(f"{'Memory Usage (MB)':<25} "
                              f"{mem_a:<20.2f} "
                              f"{mem_b:<20.2f} "
                              f"{format_improvement(improvement, 'latency'):<20}")
        
        # CPU Usage
        if 'cpu_millicores' in startup_a and 'cpu_millicores' in startup_b:
            cpu_a = startup_a['cpu_millicores']['mean']
            cpu_b = startup_b['cpu_millicores']['mean']
            improvement = calculate_improvement(cpu_a, cpu_b)
            output_lines.append(f"{'CPU Usage (millicores)':<25} "
                              f"{cpu_a:<20.2f} "
                              f"{cpu_b:<20.2f} "
                              f"{format_improvement(improvement, 'latency'):<20}")
        
        output_lines.append("")
        output_lines.append("Note: For startup metrics, lower values are better")
        output_lines.append("")
    
    for comp in phase_comparisons:
        output_lines.append("-" * 100)
        output_lines.append(f"PHASE: {comp['phase_name']}")
        output_lines.append(f"Configuration: {comp['threads']} threads, {comp['connections']} connections")
        output_lines.append("-" * 100)
        output_lines.append("")
        
        output_lines.append(f"{'Metric':<20} {session_a_id:<20} {session_b_id:<20} {'Improvement':<20}")
        output_lines.append("-" * 80)
        
        # Throughput
        output_lines.append(f"{'Throughput (req/s)':<20} "
                          f"{comp[session_a_id]['requests_per_sec']:<20.2f} "
                          f"{comp[session_b_id]['requests_per_sec']:<20.2f} "
                          f"{format_improvement(comp['improvement']['requests_per_sec'], 'throughput'):<20}")
        
        # Mean Latency
        output_lines.append(f"{'Mean Latency (ms)':<20} "
                          f"{comp[session_a_id]['latency_mean_ms']:<20.2f} "
                          f"{comp[session_b_id]['latency_mean_ms']:<20.2f} "
                          f"{format_improvement(comp['improvement']['latency_mean_ms'], 'latency'):<20}")
        
        # P99 Latency
        output_lines.append(f"{'P99 Latency (ms)':<20} "
                          f"{comp[session_a_id]['latency_p99_ms']:<20.2f} "
                          f"{comp[session_b_id]['latency_p99_ms']:<20.2f} "
                          f"{format_improvement(comp['improvement']['latency_p99_ms'], 'latency'):<20}")
        
        # Errors
        output_lines.append(f"{'Errors':<20} "
                          f"{comp[session_a_id]['errors']:<20.2f} "
                          f"{comp[session_b_id]['errors']:<20.2f} "
                          f"{format_improvement(comp['improvement']['errors'], 'errors'):<20}")
        
        output_lines.append("")
    
    output_lines.append("=" * 100)
    output_lines.append("Legend: ✓ = Improvement, ✗ = Regression")
    output_lines.append("        For throughput: higher is better")
    output_lines.append("        For latency/errors: lower is better")
    output_lines.append("=" * 100)
    
    output_text = "\n".join(output_lines)
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(output_text)
        print(f"Text comparison written to {output_file}")
    else:
        print(output_text)

PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    log_info ""
    log_info "Comparison complete!"
else
    log_error "Comparison failed"
    exit 1
fi

# Made with Bob
