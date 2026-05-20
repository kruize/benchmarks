#!/bin/bash

# ============================================================================
# Consolidate Session Data
# ============================================================================
# Combines all iteration JSON files for a session into a single JSON file
# preserving ALL metrics from the original files

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
Usage: $0 <session-directory> [output-file]

Consolidates all iteration JSON files from a session into a single JSON file,
preserving ALL metrics from the original iteration files.

Arguments:
  session-directory    Directory containing iteration JSON files
  output-file         Output JSON file (default: <session-dir>/<session-name>.json)

Example:
  $0 ./variable-load-results/ootb
  # Creates: ./variable-load-results/ootb/ootb.json

  $0 ./variable-load-results/tuned ./results/tuned-consolidated.json
  # Creates: ./results/tuned-consolidated.json

EOF
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

SESSION_DIR="$1"
OUTPUT_FILE="$2"

# Validate session directory
if [ ! -d "$SESSION_DIR" ]; then
    log_error "Session directory not found: $SESSION_DIR"
    exit 1
fi

# Extract session name from directory
SESSION_NAME=$(basename "$SESSION_DIR")

# Set default output file if not provided
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="$SESSION_DIR/${SESSION_NAME}.json"
fi

log_info "Consolidating session: $SESSION_NAME"
log_info "Session directory: $SESSION_DIR"
log_info "Output file: $OUTPUT_FILE"

# Find all iteration files (excluding phase-specific files)
ITERATION_FILES=($(find "$SESSION_DIR" -maxdepth 1 -name "*-iter[0-9]*.json" ! -name "*_phase*" | sort))

if [ ${#ITERATION_FILES[@]} -eq 0 ]; then
    log_error "No iteration files found in $SESSION_DIR"
    exit 1
fi

log_info "Found ${#ITERATION_FILES[@]} iteration files"

# Consolidate using Python - preserves ALL metrics
python3 - "${ITERATION_FILES[@]}" "$OUTPUT_FILE" "$SESSION_NAME" << 'PYTHON_SCRIPT'
import sys
import json
from pathlib import Path

def consolidate_iterations(iteration_files, output_file, session_name):
    """Consolidate all iteration files into a single JSON preserving ALL metrics."""
    
    iterations = []
    metadata = {}
    
    for iter_file in iteration_files:
        try:
            with open(iter_file, 'r') as f:
                data = json.load(f)
                
            # Extract metadata from first file
            if not metadata:
                metadata = {
                    'runtime': data.get('runtime', 'unknown'),
                    'scenario': data.get('scenario', 'unknown'),
                    'session_id': data.get('session_id', session_name)
                }
            
            # Preserve the ENTIRE iteration data structure
            # This ensures ALL metrics are kept, not just a subset
            iteration_data = dict(data)  # Copy all fields
            iteration_data['iteration'] = data.get('iteration', len(iterations) + 1)
            iterations.append(iteration_data)
            
        except Exception as e:
            print(f"Warning: Failed to process {iter_file}: {e}", file=sys.stderr)
            continue
    
    if not iterations:
        print("Error: No valid iteration data found", file=sys.stderr)
        sys.exit(1)
    
    # Create consolidated structure
    consolidated = {
        'session_name': session_name,
        'runtime': metadata['runtime'],
        'scenario': metadata['scenario'],
        'session_id': metadata['session_id'],
        'total_iterations': len(iterations),
        'iterations': iterations
    }
    
    # Write output
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(consolidated, f, indent=2)
    
    print(f"Consolidated {len(iterations)} iterations into {output_file}")

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: script <iter_file1> <iter_file2> ... <output_file> <session_name>", file=sys.stderr)
        sys.exit(1)
    
    iteration_files = sys.argv[1:-2]
    output_file = sys.argv[-2]
    session_name = sys.argv[-1]
    
    consolidate_iterations(iteration_files, output_file, session_name)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    log_info "✓ Consolidation complete: $OUTPUT_FILE"
else
    log_error "✗ Consolidation failed"
    exit 1
fi

# Made with Bob
