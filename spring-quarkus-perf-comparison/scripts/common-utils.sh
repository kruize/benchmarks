#!/bin/bash

# ============================================================================
# Common Utilities for Benchmark Scripts
# ============================================================================
# Shared functions used across multiple benchmark scripts

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Basic logging functions (no color)
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $@"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $@" >&2
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $@" >&2
}

# Colored logging functions (for interactive use)
log_info_color() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $@"
}

log_error_color() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $@" >&2
}

log_warn_color() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $@" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG]${NC} $@" >&2
    fi
}

# Validate that a directory exists and is readable
# Usage: validate_directory <path> <description>
# Returns: 0 on success, 1 on failure
validate_directory() {
    local dir_path=$1
    local description=${2:-"Directory"}
    
    if [ -z "$dir_path" ]; then
        log_error_color "$description path is empty"
        return 1
    fi
    
    if [ ! -d "$dir_path" ]; then
        log_error_color "$description not found: $dir_path"
        return 1
    fi
    
    if [ ! -r "$dir_path" ]; then
        log_error_color "$description is not readable: $dir_path"
        return 1
    fi
    
    return 0
}

# Validate that a file exists and is readable
# Usage: validate_file <path> <description>
# Returns: 0 on success, 1 on failure
validate_file() {
    local file_path=$1
    local description=${2:-"File"}
    
    if [ -z "$file_path" ]; then
        log_error_color "$description path is empty"
        return 1
    fi
    
    if [ ! -f "$file_path" ]; then
        log_error_color "$description not found: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        log_error_color "$description is not readable: $file_path"
        return 1
    fi
    
    return 0
}

# Check if jbang is installed
# Returns: 0 if installed, 1 if not
check_jbang() {
    if ! command -v jbang >/dev/null 2>&1; then
        log_error_color "JBang is not installed"
        log_error_color "Please install JBang from https://www.jbang.dev/"
        log_error_color ""
        log_error_color "Quick install:"
        log_error_color "  curl -Ls https://sh.jbang.dev | bash -s - app setup"
        return 1
    fi
    log_info_color "JBang found: $(jbang version)"
    return 0
}

# Check if required command exists
# Usage: require_command <command> <package_name>
# Returns: 0 if exists, 1 if not
require_command() {
    local cmd=$1
    local pkg=${2:-$1}
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error_color "Required command not found: $cmd"
        log_error_color "Please install: $pkg"
        return 1
    fi
    return 0
}

# Parse Hyperfoil results and generate JSON
# Usage: parse_hyperfoil_results <log_file> <phase_name> <threads> <connections> <duration>
parse_hyperfoil_results() {
    local log_file=$1
    local phase_name=$2
    local threads=$3
    local connections=$4
    local duration=$5
    
    if [ ! -f "$log_file" ]; then
        log_error "Log file not found: $log_file"
        echo "{}"
        return 1
    fi
    
    # Extract the phase line from Hyperfoil output
    # Try different phase names: "main", "loadTest", "warmup"
    local phase_line=$(grep -E "^(main|loadTest|warmup)" "$log_file" | head -1)
    
    if [ -z "$phase_line" ]; then
        log_error "Could not find phase results in log: $log_file"
        echo "{}"
        return 1
    fi
    
    # Parse values from Hyperfoil output
    # Format: "phase  scenario  578.76 req/s  17379  86.28 ms  60.92 ms  599.79 ms  98.04 ms  124.26 ms  297.80 ms  400.56 ms  599.79 ms  0  0  0 ns  17379  0  0  0  0"
    local throughput=$(echo "$phase_line" | grep -oP '\d+\.\d+\s+req/s' | grep -oP '\d+\.\d+')
    local total_requests=$(echo "$phase_line" | awk '{for(i=1;i<=NF;i++) if($i=="req/s") print $(i+1)}')
    local latency_mean=$(echo "$phase_line" | awk '{for(i=1;i<=NF;i++) if($i=="req/s") print $(i+2)}')
    local latency_p50=$(echo "$phase_line" | awk '{for(i=1;i<=NF;i++) if($i=="req/s") print $(i+8)}')
    local latency_p90=$(echo "$phase_line" | awk '{for(i=1;i<=NF;i++) if($i=="req/s") print $(i+10)}')
    local latency_p99=$(echo "$phase_line" | awk '{for(i=1;i<=NF;i++) if($i=="req/s") print $(i+12)}')
    local errors=$(echo "$phase_line" | awk '{for(i=1;i<=NF;i++) if($i=="ns") print $(i-1)}')
    local success_2xx=$(echo "$phase_line" | awk '{for(i=1;i<=NF;i++) if($i=="ns") print $(i+1)}')
    
    # Set defaults if parsing failed
    throughput=${throughput:-0}
    total_requests=${total_requests:-0}
    latency_mean=${latency_mean:-0}
    latency_p50=${latency_p50:-0}
    latency_p90=${latency_p90:-0}
    latency_p99=${latency_p99:-0}
    errors=${errors:-0}
    success_2xx=${success_2xx:-0}
    
    # Convert duration to seconds (handle formats like "1h", "30m", "1h30m", "60s")
    local duration_sec=$(echo "$duration" | awk '
        {
            total = 0
            if (match($0, /([0-9]+)h/, arr)) total += arr[1] * 3600
            if (match($0, /([0-9]+)m/, arr)) total += arr[1] * 60
            if (match($0, /([0-9]+)s/, arr)) total += arr[1]
            print total
        }
    ')
    
    # If duration_sec is 0, try simple conversion (remove 's' suffix)
    if [ "$duration_sec" = "0" ]; then
        duration_sec=$(echo "$duration" | sed 's/s$//')
    fi
    
    # Generate JSON
    cat << EOF
{
    "phase_name": "${phase_name}",
    "configuration": {
        "threads": ${threads},
        "connections": ${connections},
        "duration": "${duration}",
        "duration_seconds": ${duration_sec}
    },
    "results": {
        "tool": "hyperfoil-jbang",
        "requests_total": ${total_requests},
        "requests_per_sec": ${throughput},
        "latency_mean_ms": ${latency_mean},
        "latency_p50_ms": ${latency_p50},
        "latency_p90_ms": ${latency_p90},
        "latency_p99_ms": ${latency_p99},
        "errors": ${errors},
        "success_2xx": ${success_2xx}
    }
}
EOF
    
    return 0
}

# Made with Bob