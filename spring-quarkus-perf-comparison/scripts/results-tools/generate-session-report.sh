#!/bin/bash

# ============================================================================
# Generate Session HTML Report
# ============================================================================
# Generates HTML reports from session-based test results
# Supports both single session reports and cross-session comparisons

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
SESSION_A=""
SESSION_B=""
OUTPUT_FILE=""
REPORT_TYPE="single"  # single or comparison

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
Usage: $0 [OPTIONS]

Generate HTML reports from session-based test results.

Single Session Report:
  --session <dir>          Session directory to generate report for
  --output <file>          Output HTML file (default: <session-dir>/report.html)

Comparison Report:
  --session-a <dir>        First session directory
  --session-b <dir>        Second session directory
  --output <file>          Output HTML file (default: ./session-comparison.html)

Options:
  --help                   Show this help message

Examples:
  # Generate report for single session
  $0 --session ./variable-load-results/session-baseline

  # Generate comparison report
  $0 --session-a ./variable-load-results/session-baseline \\
     --session-b ./variable-load-results/session-optimized \\
     --output comparison-report.html

Note: Sessions must have aggregated.json files (run aggregate-session.sh first)

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --session)
            SESSION_A="$2"
            REPORT_TYPE="single"
            shift 2
            ;;
        --session-a)
            SESSION_A="$2"
            REPORT_TYPE="comparison"
            shift 2
            ;;
        --session-b)
            SESSION_B="$2"
            REPORT_TYPE="comparison"
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

# Validate inputs
if [ "$REPORT_TYPE" = "single" ]; then
    if [ -z "$SESSION_A" ]; then
        log_error "--session is required for single session report"
        usage
    fi
    if [ ! -d "$SESSION_A" ]; then
        log_error "Session directory not found: $SESSION_A"
        exit 1
    fi
    if [ ! -f "${SESSION_A}/aggregated.json" ]; then
        log_error "aggregated.json not found in $SESSION_A"
        log_error "Run aggregate-session.sh first"
        exit 1
    fi
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="${SESSION_A}/report.html"
    fi
else
    if [ -z "$SESSION_A" ] || [ -z "$SESSION_B" ]; then
        log_error "Both --session-a and --session-b are required for comparison report"
        usage
    fi
    if [ ! -d "$SESSION_A" ] || [ ! -d "$SESSION_B" ]; then
        log_error "Session directories not found"
        exit 1
    fi
    if [ ! -f "${SESSION_A}/aggregated.json" ] || [ ! -f "${SESSION_B}/aggregated.json" ]; then
        log_error "aggregated.json not found in one or both sessions"
        log_error "Run aggregate-session.sh first"
        exit 1
    fi
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="./session-comparison.html"
    fi
fi

log_info "========================================="
log_info "Generating Session HTML Report"
log_info "========================================="
log_info "Report Type: $REPORT_TYPE"
log_info "Output: $OUTPUT_FILE"
log_info ""

# For now, use the existing comparison tools to generate data, then create HTML
if [ "$REPORT_TYPE" = "single" ]; then
    log_info "Generating single session report for: $SESSION_A"
    
    # Use analyze-session.sh to get variability data
    TEMP_ANALYSIS=$(mktemp)
    "${SCRIPT_DIR}/analyze-session.sh" --session-dir "$SESSION_A" --format json --output "$TEMP_ANALYSIS"
    
    # Generate HTML
    export SESSION_A OUTPUT_FILE TEMP_ANALYSIS
    python3 - "$SESSION_A" "$OUTPUT_FILE" "$TEMP_ANALYSIS" << 'PYTHON_SCRIPT'
import json
import sys
import os

session_dir = sys.argv[1]
output_file = sys.argv[2]
temp_analysis = sys.argv[3]

# Load data
with open(os.path.join(session_dir, 'aggregated.json'), 'r') as f:
    agg_data = json.load(f)

with open(temp_analysis, 'r') as f:
    analysis_data = json.load(f)

session_id = agg_data.get('session_id', 'unknown')
runtime = agg_data.get('runtime', 'unknown')
iterations = agg_data.get('total_iterations', 0)

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Session Report: {session_id}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }}
        h2 {{ color: #555; margin-top: 30px; }}
        .metadata {{ background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        .metadata p {{ margin: 5px 0; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th, td {{ padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }}
        th {{ background-color: #4CAF50; color: white; }}
        tr:hover {{ background-color: #f5f5f5; }}
        .phase-section {{ margin: 30px 0; padding: 20px; background: #fafafa; border-left: 4px solid #4CAF50; }}
        .metric-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin: 15px 0; }}
        .metric-card {{ background: white; padding: 15px; border-radius: 5px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
        .metric-card h4 {{ margin: 0 0 10px 0; color: #666; font-size: 14px; }}
        .metric-value {{ font-size: 24px; font-weight: bold; color: #333; }}
        .metric-detail {{ font-size: 12px; color: #999; margin-top: 5px; }}
        .stability-excellent {{ color: #4CAF50; }}
        .stability-good {{ color: #8BC34A; }}
        .stability-moderate {{ color: #FF9800; }}
        .stability-poor {{ color: #F44336; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Session Performance Report</h1>
        
        <div class="metadata">
            <p><strong>Session ID:</strong> {session_id}</p>
            <p><strong>Runtime:</strong> {runtime}</p>
            <p><strong>Total Iterations:</strong> {iterations}</p>
            <p><strong>Test Type:</strong> Multi-Phase Variable Load</p>
        </div>

        <h2>Phase Performance Summary</h2>
"""

for phase in agg_data.get('phases', []):
    phase_name = phase['phase_name']
    threads = phase['threads']
    connections = phase['connections']
    
    # Find corresponding analysis
    phase_analysis = next((p for p in analysis_data['phase_analyses'] if p['phase_name'] == phase_name), None)
    
    stability_class = "stability-excellent"
    if phase_analysis:
        stability = phase_analysis.get('overall_stability_score', 0)
        if stability < 70:
            stability_class = "stability-poor"
        elif stability < 80:
            stability_class = "stability-moderate"
        elif stability < 90:
            stability_class = "stability-good"
    
    html += f"""
        <div class="phase-section">
            <h3>Phase: {phase_name}</h3>
            <p><strong>Configuration:</strong> {threads} threads, {connections} connections</p>
            {f'<p><strong>Stability Score:</strong> <span class="{stability_class}">{phase_analysis["overall_stability_score"]:.1f}/100</span></p>' if phase_analysis else ''}
            
            <div class="metric-grid">
                <div class="metric-card">
                    <h4>Throughput (req/s)</h4>
                    <div class="metric-value">{phase['requests_per_sec']['mean']:.2f}</div>
                    <div class="metric-detail">± {phase['requests_per_sec']['stddev']:.2f} (CV: {phase_analysis['requests_per_sec']['cv']:.1f}%)</div>
                    <div class="metric-detail">Range: {phase['requests_per_sec']['min']:.2f} - {phase['requests_per_sec']['max']:.2f}</div>
                </div>
                
                <div class="metric-card">
                    <h4>Mean Latency (ms)</h4>
                    <div class="metric-value">{phase['latency_mean_ms']['mean']:.2f}</div>
                    <div class="metric-detail">± {phase['latency_mean_ms']['stddev']:.2f} (CV: {phase_analysis['latency_mean_ms']['cv']:.1f}%)</div>
                    <div class="metric-detail">Range: {phase['latency_mean_ms']['min']:.2f} - {phase['latency_mean_ms']['max']:.2f}</div>
                </div>
                
                <div class="metric-card">
                    <h4>P99 Latency (ms)</h4>
                    <div class="metric-value">{phase['latency_p99_ms']['mean']:.2f}</div>
                    <div class="metric-detail">± {phase['latency_p99_ms']['stddev']:.2f} (CV: {phase_analysis['latency_p99_ms']['cv']:.1f}%)</div>
                    <div class="metric-detail">Range: {phase['latency_p99_ms']['min']:.2f} - {phase['latency_p99_ms']['max']:.2f}</div>
                </div>
                
                <div class="metric-card">
                    <h4>Errors</h4>
                    <div class="metric-value">{phase['errors']['mean']:.2f}</div>
                    <div class="metric-detail">± {phase['errors']['stddev']:.2f}</div>
                    <div class="metric-detail">Range: {phase['errors']['min']:.2f} - {phase['errors']['max']:.2f}</div>
                </div>
            </div>
        </div>
"""

html += """
    </div>
</body>
</html>
"""

with open(output_file, 'w') as f:
    f.write(html)

print(f"HTML report generated: {output_file}")

PYTHON_SCRIPT

    rm -f "$TEMP_ANALYSIS"
    
else
    log_info "Generating comparison report: $SESSION_A vs $SESSION_B"
    
    # Use compare-sessions.sh to get comparison data
    TEMP_COMPARISON=$(mktemp)
    "${SCRIPT_DIR}/compare-sessions.sh" --session-a "$SESSION_A" --session-b "$SESSION_B" --format json --output "$TEMP_COMPARISON"
    
    # Get variability analysis for both sessions
    TEMP_ANALYSIS_A=$(mktemp)
    TEMP_ANALYSIS_B=$(mktemp)
    "${SCRIPT_DIR}/analyze-session.sh" --session-dir "$SESSION_A" --format json --output "$TEMP_ANALYSIS_A"
    "${SCRIPT_DIR}/analyze-session.sh" --session-dir "$SESSION_B" --format json --output "$TEMP_ANALYSIS_B"
    
    # Generate HTML comparison report with variability data
    export SESSION_A SESSION_B OUTPUT_FILE TEMP_COMPARISON TEMP_ANALYSIS_A TEMP_ANALYSIS_B
    python3 - "$SESSION_A" "$SESSION_B" "$OUTPUT_FILE" "$TEMP_COMPARISON" "$TEMP_ANALYSIS_A" "$TEMP_ANALYSIS_B" << 'PYTHON_SCRIPT'
import json
import sys

session_a_dir = sys.argv[1]
session_b_dir = sys.argv[2]
output_file = sys.argv[3]
temp_comparison = sys.argv[4]
temp_analysis_a = sys.argv[5]
temp_analysis_b = sys.argv[6]

# Load comparison data
with open(temp_comparison, 'r') as f:
    comp_data = json.load(f)

# Load variability analysis data
with open(temp_analysis_a, 'r') as f:
    analysis_a = json.load(f)
with open(temp_analysis_b, 'r') as f:
    analysis_b = json.load(f)

# Load aggregated data for stddev and ranges
import os
with open(os.path.join(session_a_dir, 'aggregated.json'), 'r') as f:
    agg_a = json.load(f)
with open(os.path.join(session_b_dir, 'aggregated.json'), 'r') as f:
    agg_b = json.load(f)

# Extract session IDs from the comparison data keys
session_ids = [k for k in comp_data.keys() if k not in ['runtime', 'phase_comparisons']]
session_a_id = session_ids[0] if len(session_ids) > 0 else 'Session A'
session_b_id = session_ids[1] if len(session_ids) > 1 else 'Session B'

runtime = comp_data.get('runtime', 'unknown')
session_a_info = comp_data.get(session_a_id, {})
session_b_info = comp_data.get(session_b_id, {})
phase_comparisons = comp_data.get('phase_comparisons', [])

def format_improvement(value):
    if value is None:
        return '<span class="neutral">N/A</span>'
    if value > 0:
        return f'<span class="positive">+{value:.1f}%</span>'
    elif value < 0:
        return f'<span class="positive">{value:.1f}%</span>'
    else:
        return '<span class="neutral">0.0%</span>'

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Performance Comparison: {session_a_id} vs {session_b_id}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
        .container {{ max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }}
        h2 {{ color: #555; margin-top: 30px; border-bottom: 2px solid #ddd; padding-bottom: 8px; }}
        .metadata {{ background: #e8f5e9; padding: 20px; border-radius: 5px; margin: 20px 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }}
        .metadata-item {{ background: white; padding: 15px; border-radius: 5px; }}
        .metadata-item h3 {{ margin: 0 0 10px 0; color: #4CAF50; font-size: 16px; }}
        .metadata-item p {{ margin: 5px 0; color: #666; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th, td {{ padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }}
        th {{ background-color: #4CAF50; color: white; font-weight: bold; }}
        tr:hover {{ background-color: #f5f5f5; }}
        .phase-section {{ margin: 30px 0; padding: 25px; background: #fafafa; border-left: 4px solid #4CAF50; border-radius: 5px; }}
        .phase-header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }}
        .phase-header h3 {{ margin: 0; color: #333; }}
        .phase-config {{ color: #666; font-size: 14px; }}
        .positive {{ color: #4CAF50; font-weight: bold; }}
        .negative {{ color: #F44336; font-weight: bold; }}
        .neutral {{ color: #999; }}
        .metric-value {{ font-weight: bold; }}
        .comparison-table th:nth-child(1) {{ width: 25%; }}
        .comparison-table th:nth-child(2) {{ width: 25%; text-align: right; }}
        .comparison-table th:nth-child(3) {{ width: 25%; text-align: right; }}
        .comparison-table th:nth-child(4) {{ width: 25%; text-align: center; }}
        .comparison-table td:nth-child(2), .comparison-table td:nth-child(3) {{ text-align: right; }}
        .comparison-table td:nth-child(4) {{ text-align: center; }}
        .summary-box {{ background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 5px; }}
        .summary-box h3 {{ margin: 0 0 10px 0; color: #856404; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Performance Comparison Report</h1>
        <h2 style="color: #4CAF50; border: none;">{session_a_id} vs {session_b_id}</h2>
        
        <div class="metadata">
            <div class="metadata-item">
                <h3>{session_a_id}</h3>
                <p><strong>Runtime:</strong> {runtime}</p>
                <p><strong>Iterations:</strong> {session_a_info.get('iterations', 'N/A')}</p>
            </div>
            <div class="metadata-item">
                <h3>{session_b_id}</h3>
                <p><strong>Runtime:</strong> {runtime}</p>
                <p><strong>Iterations:</strong> {session_b_info.get('iterations', 'N/A')}</p>
            </div>
        </div>

        <h2>Phase-by-Phase Comparison</h2>
"""

for phase in phase_comparisons:
    phase_name = phase['phase_name']
    threads = phase['threads']
    connections = phase['connections']
    
    session_a_data = phase.get(session_a_id, {})
    session_b_data = phase.get(session_b_id, {})
    improvements = phase.get('improvement', {})
    
    # Find variability data and aggregated data for this phase
    phase_analysis_a = next((p for p in analysis_a.get('phase_analyses', []) if p['phase_name'] == phase_name), {})
    phase_analysis_b = next((p for p in analysis_b.get('phase_analyses', []) if p['phase_name'] == phase_name), {})
    phase_agg_a = next((p for p in agg_a.get('phases', []) if p['phase_name'] == phase_name), {})
    phase_agg_b = next((p for p in agg_b.get('phases', []) if p['phase_name'] == phase_name), {})
    
    html += f"""
        <div class="phase-section">
            <div class="phase-header">
                <h3>Phase: {phase_name}</h3>
                <span class="phase-config">{threads} threads, {connections} connections</span>
            </div>
            
            <table class="comparison-table">
                <thead>
                    <tr>
                        <th>Metric</th>
                        <th>{session_a_id}</th>
                        <th>{session_b_id}</th>
                        <th>Improvement</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>Throughput (req/s)</td>
                        <td class="metric-value">
                            {session_a_data.get('requests_per_sec', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_a.get('requests_per_sec', {}).get('stddev', 0):.2f} (CV: {phase_analysis_a.get('requests_per_sec', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_a.get('requests_per_sec', {}).get('min', 0):.2f} - {phase_agg_a.get('requests_per_sec', {}).get('max', 0):.2f}</small>
                        </td>
                        <td class="metric-value">
                            {session_b_data.get('requests_per_sec', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_b.get('requests_per_sec', {}).get('stddev', 0):.2f} (CV: {phase_analysis_b.get('requests_per_sec', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_b.get('requests_per_sec', {}).get('min', 0):.2f} - {phase_agg_b.get('requests_per_sec', {}).get('max', 0):.2f}</small>
                        </td>
                        <td>{format_improvement(improvements.get('requests_per_sec'))}</td>
                    </tr>
                    <tr>
                        <td>Mean Latency (ms)</td>
                        <td class="metric-value">
                            {session_a_data.get('latency_mean_ms', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_a.get('latency_mean_ms', {}).get('stddev', 0):.2f} (CV: {phase_analysis_a.get('latency_mean_ms', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_a.get('latency_mean_ms', {}).get('min', 0):.2f} - {phase_agg_a.get('latency_mean_ms', {}).get('max', 0):.2f}</small>
                        </td>
                        <td class="metric-value">
                            {session_b_data.get('latency_mean_ms', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_b.get('latency_mean_ms', {}).get('stddev', 0):.2f} (CV: {phase_analysis_b.get('latency_mean_ms', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_b.get('latency_mean_ms', {}).get('min', 0):.2f} - {phase_agg_b.get('latency_mean_ms', {}).get('max', 0):.2f}</small>
                        </td>
                        <td>{format_improvement(improvements.get('latency_mean_ms'))}</td>
                    </tr>
                    <tr>
                        <td>P99 Latency (ms)</td>
                        <td class="metric-value">
                            {session_a_data.get('latency_p99_ms', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_a.get('latency_p99_ms', {}).get('stddev', 0):.2f} (CV: {phase_analysis_a.get('latency_p99_ms', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_a.get('latency_p99_ms', {}).get('min', 0):.2f} - {phase_agg_a.get('latency_p99_ms', {}).get('max', 0):.2f}</small>
                        </td>
                        <td class="metric-value">
                            {session_b_data.get('latency_p99_ms', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_b.get('latency_p99_ms', {}).get('stddev', 0):.2f} (CV: {phase_analysis_b.get('latency_p99_ms', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_b.get('latency_p99_ms', {}).get('min', 0):.2f} - {phase_agg_b.get('latency_p99_ms', {}).get('max', 0):.2f}</small>
                        </td>
                        <td>{format_improvement(improvements.get('latency_p99_ms'))}</td>
                    </tr>
                    <tr>
                        <td>Errors</td>
                        <td class="metric-value">
                            {session_a_data.get('errors', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_a.get('errors', {}).get('stddev', 0):.2f} (CV: {phase_analysis_a.get('errors', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_a.get('errors', {}).get('min', 0):.2f} - {phase_agg_a.get('errors', {}).get('max', 0):.2f}</small>
                        </td>
                        <td class="metric-value">
                            {session_b_data.get('errors', 0):.2f}<br/>
                            <small style="color:#666;">± {phase_agg_b.get('errors', {}).get('stddev', 0):.2f} (CV: {phase_analysis_b.get('errors', {}).get('cv', 0):.1f}%)</small><br/>
                            <small style="color:#999;">Range: {phase_agg_b.get('errors', {}).get('min', 0):.2f} - {phase_agg_b.get('errors', {}).get('max', 0):.2f}</small>
                        </td>
                        <td>{format_improvement(improvements.get('errors'))}</td>
                    </tr>
                </tbody>
            </table>
        </div>
"""

html += """
        <div class="summary-box">
            <h3>Note</h3>
            <p>Positive percentages indicate improvement. For throughput, higher is better. For latency and errors, lower is better.</p>
        </div>
    </div>
</body>
</html>
"""

with open(output_file, 'w') as f:
    f.write(html)

print(f"HTML comparison report generated: {output_file}")

PYTHON_SCRIPT
    
    rm -f "$TEMP_COMPARISON" "$TEMP_ANALYSIS_A" "$TEMP_ANALYSIS_B"
fi

log_info ""
log_info "Report generated successfully: $OUTPUT_FILE"

# Made with Bob
