#!/bin/bash

# ============================================================================
# Combine Multiple Sessions
# ============================================================================
# Combines multiple session JSON files into a single combined JSON file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $@"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $@"
}

usage() {
    cat << EOF
Usage: $0 <session-file1> <session-file2> [session-file3...] --output <output-file>

Combines multiple session JSON files into a single combined JSON file.

Arguments:
  session-file1, session-file2, ...  Session JSON files to combine
  --output <file>                     Output combined JSON file

Example:
  $0 ./variable-load-results/ootb/ootb.json \\
     ./variable-load-results/tuned/tuned.json \\
     --output ./variable-load-results/combined.json

EOF
    exit 1
}

# Parse arguments
SESSION_FILES=()
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            SESSION_FILES+=("$1")
            shift
            ;;
    esac
done

# Validate inputs
if [ ${#SESSION_FILES[@]} -lt 2 ]; then
    log_error "At least 2 session files are required"
    usage
fi

if [ -z "$OUTPUT_FILE" ]; then
    log_error "Output file is required (--output)"
    usage
fi

# Validate all session files exist
for file in "${SESSION_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Session file not found: $file"
        exit 1
    fi
done

log_info "Combining ${#SESSION_FILES[@]} session files"
log_info "Output file: $OUTPUT_FILE"

# Combine using Python
python3 - "${SESSION_FILES[@]}" "$OUTPUT_FILE" << 'PYTHON_SCRIPT'
import sys
import json
from pathlib import Path

def combine_sessions(session_files, output_file):
    """Combine multiple session JSON files into a single file."""
    
    sessions = {}
    
    for session_file in session_files:
        try:
            with open(session_file, 'r') as f:
                data = json.load(f)
            
            session_name = data.get('session_name', Path(session_file).stem)
            sessions[session_name] = data
            
            print(f"Loaded session: {session_name} ({data.get('total_iterations', 0)} iterations)")
            
        except Exception as e:
            print(f"Warning: Failed to process {session_file}: {e}", file=sys.stderr)
            continue
    
    if not sessions:
        print("Error: No valid session data found", file=sys.stderr)
        sys.exit(1)
    
    # Create combined structure
    combined = {
        'total_sessions': len(sessions),
        'sessions': sessions
    }
    
    # Write output
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(combined, f, indent=2)
    
    print(f"Combined {len(sessions)} sessions into {output_file}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: script <session_file1> <session_file2> ... <output_file>", file=sys.stderr)
        sys.exit(1)
    
    session_files = sys.argv[1:-1]
    output_file = sys.argv[-1]
    
    combine_sessions(session_files, output_file)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    log_info "✓ Combination complete: $OUTPUT_FILE"
else
    log_error "✗ Combination failed"
    exit 1
fi

# Made with Bob
