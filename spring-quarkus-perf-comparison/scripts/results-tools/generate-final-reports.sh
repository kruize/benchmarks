#!/bin/bash

# ============================================================================
# Generate Final Reports
# ============================================================================
# Master script to generate all final output files:
# 1. Individual session JSON files (ootb.json, tuned.json, etc.)
# 2. Combined JSON file (combined.json)
# 3. Comparison text file (comparison.txt)
# 4. Comparison HTML report (comparison-report.html)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $@"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $@"
}

log_step() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [STEP]${NC} $@"
}

usage() {
    cat << EOF
Usage: $0 <results-directory>

Generates all final output files from session-based test results:
  - Individual session JSON files (e.g., ootb.json, tuned.json)
  - Combined JSON file (combined.json)
  - Comparison text file (comparison.txt)
  - Comparison HTML report (comparison-report.html)

Arguments:
  results-directory    Directory containing session subdirectories

Example:
  $0 ./variable-load-results

  This will process all sessions in ./variable-load-results/ and generate:
    - ./variable-load-results/ootb.json
    - ./variable-load-results/tuned.json
    - ./variable-load-results/combined.json
    - ./variable-load-results/comparison.txt
    - ./variable-load-results/comparison-report.html

EOF
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

RESULTS_DIR="$1"

# Validate results directory
if [ ! -d "$RESULTS_DIR" ]; then
    log_error "Results directory not found: $RESULTS_DIR"
    exit 1
fi

log_info "Processing results from: $RESULTS_DIR"
echo ""

# Find all session directories
SESSION_DIRS=($(find "$RESULTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort))

if [ ${#SESSION_DIRS[@]} -eq 0 ]; then
    log_error "No session directories found in $RESULTS_DIR"
    exit 1
fi

log_info "Found ${#SESSION_DIRS[@]} session directories"
for dir in "${SESSION_DIRS[@]}"; do
    echo "  - $(basename "$dir")"
done
echo ""

# Step 1: Consolidate each session
log_step "Step 1: Consolidating individual sessions"
SESSION_FILES=()
for session_dir in "${SESSION_DIRS[@]}"; do
    session_name=$(basename "$session_dir")
    output_file="$RESULTS_DIR/${session_name}.json"
    
    log_info "Consolidating session: $session_name"
    bash "$SCRIPT_DIR/consolidate-session.sh" "$session_dir" "$output_file"
    
    if [ -f "$output_file" ]; then
        SESSION_FILES+=("$output_file")
    fi
done
echo ""

# Step 2: Combine all sessions
log_step "Step 2: Combining all sessions"
COMBINED_FILE="$RESULTS_DIR/combined.json"
bash "$SCRIPT_DIR/combine-sessions.sh" "${SESSION_FILES[@]}" --output "$COMBINED_FILE"
echo ""

# Step 3: Generate comparison files
log_step "Step 3: Generating comparison reports"

# Determine session pairs for comparison
if [ ${#SESSION_DIRS[@]} -eq 2 ]; then
    SESSION_A="${SESSION_DIRS[0]}"
    SESSION_B="${SESSION_DIRS[1]}"
    SESSION_A_NAME=$(basename "$SESSION_A")
    SESSION_B_NAME=$(basename "$SESSION_B")
    
    log_info "Comparing: $SESSION_A_NAME vs $SESSION_B_NAME"
    
    # Generate comparison text file directly
    COMPARISON_TXT="$RESULTS_DIR/${SESSION_A_NAME}-vs-${SESSION_B_NAME}-comparison.txt"
    
    bash "$SCRIPT_DIR/compare-sessions.sh" \
        --session-a "$SESSION_A" \
        --session-b "$SESSION_B" \
        --output "$COMPARISON_TXT"
    
    # Generate HTML report
    bash "$SCRIPT_DIR/generate-session-report.sh" \
        --session-a "$SESSION_A" \
        --session-b "$SESSION_B" \
        --output "$RESULTS_DIR/comparison-report.html"
    
    # Clean up intermediate JSON comparison file (we only need txt and html)
    if [ -f "$COMPARISON_JSON" ]; then
        rm "$COMPARISON_JSON"
    fi
    
else
    log_info "Skipping comparison (requires exactly 2 sessions, found ${#SESSION_DIRS[@]})"
fi
echo ""

# Summary
log_step "Summary of generated files:"
echo ""
echo "Session JSON files:"
for file in "${SESSION_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "  ✓ $(basename "$file") ($size)"
    fi
done
echo ""

if [ -f "$COMBINED_FILE" ]; then
    size=$(du -h "$COMBINED_FILE" | cut -f1)
    echo "Combined JSON:"
    echo "  ✓ combined.json ($size)"
    echo ""
fi

if [ -f "$COMPARISON_TXT" ]; then
    size=$(du -h "$COMPARISON_TXT" | cut -f1)
    echo "Comparison files:"
    echo "  ✓ $(basename "$COMPARISON_TXT") ($size)"
fi

if [ -f "$RESULTS_DIR/comparison-report.html" ]; then
    size=$(du -h "$RESULTS_DIR/comparison-report.html" | cut -f1)
    echo "  ✓ comparison-report.html ($size)"
fi

echo ""
log_info "✓ All reports generated successfully!"

# Made with Bob
