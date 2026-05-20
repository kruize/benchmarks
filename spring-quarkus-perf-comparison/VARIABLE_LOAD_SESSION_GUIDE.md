# Variable Load Testing with Session-Based Analysis

This guide explains how to use the session-based iteration tracking and analysis features for multi-phase variable load testing.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Session Concepts](#session-concepts)
4. [Complete Workflow](#complete-workflow)
5. [Analysis Tools](#analysis-tools)
6. [Use Cases](#use-cases)
7. [Best Practices](#best-practices)

## Overview

The session-based testing framework allows you to:

- **Run multiple iterations** of the same test configuration
- **Track iterations automatically** within a session
- **Compare different configurations** (e.g., OOTB vs Tuned)
- **Analyze variability** within a session to measure consistency
- **Aggregate metrics** across iterations for statistical analysis

### Key Features

- ✅ Automatic iteration numbering
- ✅ Phase-level statistical aggregation (mean, median, stddev)
- ✅ Cross-session comparison (A vs B)
- ✅ Within-session variability analysis
- ✅ Coefficient of Variation (CV) for consistency measurement
- ✅ Compatible with existing comparison and reporting tools

## Quick Start

### 1. Run Tests with Session Tracking

```bash
# Run baseline configuration (iteration 1)
./scripts/run-variable-load-multi-phase.sh \
  --runtime quarkus3-jvm \
  --scenario ootb \
  --session-id baseline \
  --duration custom \
  --phase-duration 3m

# Run again (iteration 2 - auto-detected)
./scripts/run-variable-load-multi-phase.sh \
  --runtime quarkus3-jvm \
  --scenario ootb \
  --session-id baseline \
  --duration custom \
  --phase-duration 3m

# Run optimized configuration
./scripts/run-variable-load-multi-phase.sh \
  --runtime quarkus3-jvm \
  --scenario tuned \
  --session-id optimized \
  --duration custom \
  --phase-duration 3m
```

### 2. Aggregate Session Results

```bash
# Aggregate baseline session
./scripts/results-tools/aggregate-session.sh \
  --session-dir ./variable-load-results/session-baseline

# Aggregate optimized session
./scripts/results-tools/aggregate-session.sh \
  --session-dir ./variable-load-results/session-optimized
```

### 3. Compare Sessions

```bash
# Compare OOTB vs Tuned
./scripts/results-tools/compare-sessions.sh \
  --session-a ./variable-load-results/session-baseline \
  --session-b ./variable-load-results/session-optimized
```

### 4. Analyze Variability

```bash
# Check consistency within baseline session
./scripts/results-tools/analyze-session.sh \
  --session-dir ./variable-load-results/session-baseline
```

## Session Concepts

### What is a Session?

A **session** is a group of related test runs with the same configuration. Each run within a session is called an **iteration**.

```
session-baseline/
├── quarkus3-jvm-ootb-iter1.json    # First run
├── quarkus3-jvm-ootb-iter2.json    # Second run
├── quarkus3-jvm-ootb-iter3.json    # Third run
└── aggregated.json                  # Statistical summary
```

### Session ID

The `--session-id` parameter groups related test runs:

- **Same session-id** = iterations of the same configuration
- **Different session-ids** = different configurations to compare

### Iteration Numbers

Iteration numbers are **automatically detected** by counting existing files in the session directory. You can also specify `--iteration` explicitly if needed.

### Output Structure

```
variable-load-results/
├── session-baseline/
│   ├── quarkus3-jvm-ootb-iter1.json
│   ├── quarkus3-jvm-ootb-iter2.json
│   ├── quarkus3-jvm-ootb-iter3.json
│   ├── aggregated.json
│   └── [phase logs and metadata]
└── session-optimized/
    ├── quarkus3-jvm-tuned-iter1.json
    ├── quarkus3-jvm-tuned-iter2.json
    ├── aggregated.json
    └── [phase logs and metadata]
```

## Complete Workflow

### Step 1: Run Multiple Iterations

Run the same test configuration multiple times (3-5 iterations recommended):

```bash
# Iteration 1
./scripts/run-variable-load-multi-phase.sh \
  --runtime quarkus3-jvm \
  --scenario ootb \
  --session-id baseline \
  --duration 4h

# Iteration 2 (auto-detected)
./scripts/run-variable-load-multi-phase.sh \
  --runtime quarkus3-jvm \
  --scenario ootb \
  --session-id baseline \
  --duration 4h

# Iteration 3 (auto-detected)
./scripts/run-variable-load-multi-phase.sh \
  --runtime quarkus3-jvm \
  --scenario ootb \
  --session-id baseline \
  --duration 4h
```

**Output:**
```
variable-load-results/session-baseline/
├── quarkus3-jvm-ootb-iter1.json
├── quarkus3-jvm-ootb-iter2.json
└── quarkus3-jvm-ootb-iter3.json
```

### Step 2: Aggregate Session Data

Calculate statistics across all iterations:

```bash
./scripts/results-tools/aggregate-session.sh \
  --session-dir ./variable-load-results/session-baseline
```

**Output:** `session-baseline/aggregated.json`

This file contains mean, median, stddev, min, max for each metric in each phase.

### Step 3: Analyze Variability

Check how consistent the performance is:

```bash
./scripts/results-tools/analyze-session.sh \
  --session-dir ./variable-load-results/session-baseline
```

**Output:**
```
PHASE: low
Configuration: 2 threads, 50 connections
Overall Stability Score: 95.23/100

THROUGHPUT:
  Mean:        1234.56 req/s
  Std Dev:     45.67 req/s
  CV:          3.70%
  Range:       123.45 req/s
  Stability:   96.30/100
```

### Step 4: Run Alternative Configuration

Test a different configuration (e.g., tuned):

```bash
# Run tuned configuration (3 iterations)
for i in {1..3}; do
  ./scripts/run-variable-load-multi-phase.sh \
    --runtime quarkus3-jvm \
    --scenario tuned \
    --session-id optimized \
    --duration 4h
done
```

### Step 5: Aggregate Alternative Session

```bash
./scripts/results-tools/aggregate-session.sh \
  --session-dir ./variable-load-results/session-optimized
```

### Step 6: Compare Sessions

Compare the two configurations:

```bash
./scripts/results-tools/compare-sessions.sh \
  --session-a ./variable-load-results/session-baseline \
  --session-b ./variable-load-results/session-optimized
```

**Output:**
```
PHASE: peak
Configuration: 6 threads, 500 connections

Metric               Session A            Session B            Improvement
--------------------------------------------------------------------------------
Throughput (req/s)   1234.56              1456.78              +18.00% ✓
Mean Latency (ms)    45.67                38.90                -14.82% ✓
P99 Latency (ms)     123.45               98.76                -20.00% ✓
```

## Analysis Tools

### 1. aggregate-session.sh

**Purpose:** Calculate statistics across iterations

**Usage:**
```bash
./scripts/results-tools/aggregate-session.sh \
  --session-dir <session-directory> \
  [--output <output-file>]
```

**Output:** JSON file with mean, median, stddev, min, max for each metric

**When to use:**
- After running multiple iterations
- Before comparing sessions
- Before analyzing variability

### 2. compare-sessions.sh

**Purpose:** Compare two sessions phase-by-phase

**Usage:**
```bash
./scripts/results-tools/compare-sessions.sh \
  --session-a <session-A-dir> \
  --session-b <session-B-dir> \
  [--format text|json] \
  [--output <output-file>]
```

**Output:** Phase-level comparison showing improvements/regressions

**When to use:**
- Comparing OOTB vs Tuned
- Comparing different JVM versions
- Comparing different configurations

### 3. analyze-session.sh

**Purpose:** Analyze within-session variability

**Usage:**
```bash
./scripts/results-tools/analyze-session.sh \
  --session-dir <session-directory> \
  [--format text|json] \
  [--output <output-file>]
```

**Output:** Variability metrics (CV, stability scores)

**When to use:**
- Checking test consistency
- Determining if more iterations are needed
- Validating test reliability
### 4. generate-final-reports.sh

**Purpose:** Generate all final output files in one command

**Usage:**
```bash
./scripts/results-tools/generate-final-reports.sh <results-directory>
```

**Example:**
```bash
./scripts/results-tools/generate-final-reports.sh ./variable-load-results
```

**What it does:**
1. Consolidates each session into a single JSON file
2. Combines all sessions into one JSON file
3. Generates comparison text file
4. Generates comparison HTML report

**Output Files:**
```
variable-load-results/
├── session-ootb.json                              # All ootb iterations with full metrics
├── session-tuned.json                             # All tuned iterations with full metrics
├── combined.json                                  # Both sessions combined
├── session-ootb-vs-session-tuned-comparison.txt   # Text comparison table
└── comparison-report.html                         # HTML comparison report
```

**File Descriptions:**

- **session-*.json**: Contains all iterations for a session with complete metrics from each run
  - Preserves ALL original metrics from iteration files
  - Useful for detailed analysis and custom processing
  - Structure: `{ session_name, runtime, scenario, total_iterations, iterations: [...] }`

- **combined.json**: All sessions in one file
  - Top-level structure: `{ total_sessions, sessions: { "session-name": {...}, ... } }`
  - Useful for programmatic access to all data

- **session-*-vs-*-comparison.txt**: Human-readable comparison table
  - Phase-by-phase performance comparison
  - Shows actual values for both sessions
  - Includes improvement percentages with ✓/✗ indicators

- **comparison-report.html**: Interactive HTML report
  - Visual comparison with charts
  - Includes variability analysis
  - Easy to share with stakeholders

**When to use:**
- After completing all test runs
- When you need a complete set of output files
- For final reporting and analysis


## Use Cases

### Use Case 1: OOTB vs Tuned Comparison

**Goal:** Compare out-of-the-box vs tuned configuration

```bash
# 1. Run OOTB (3 iterations)
for i in {1..3}; do
  ./scripts/run-variable-load-multi-phase.sh \
    --runtime quarkus3-jvm --scenario ootb \
    --session-id baseline --duration 4h
done

# 2. Run Tuned (3 iterations)
for i in {1..3}; do
  ./scripts/run-variable-load-multi-phase.sh \
    --runtime quarkus3-jvm --scenario tuned \
    --session-id optimized --duration 4h
done

# 3. Aggregate both
./scripts/results-tools/aggregate-session.sh --session-dir ./variable-load-results/session-baseline
./scripts/results-tools/aggregate-session.sh --session-dir ./variable-load-results/session-optimized

# 4. Compare
./scripts/results-tools/compare-sessions.sh \
  --session-a ./variable-load-results/session-baseline \
  --session-b ./variable-load-results/session-optimized
```

### Use Case 2: Quick Testing with Short Phases

**Goal:** Fast iteration for development/debugging

```bash
# Run 3 quick iterations (3 minutes per phase)
for i in {1..3}; do
  ./scripts/run-variable-load-multi-phase.sh \
    --runtime quarkus3-jvm --scenario ootb \
    --session-id quick-test \
    --duration custom --phase-duration 3m
done

# Analyze consistency
./scripts/results-tools/aggregate-session.sh \
  --session-dir ./variable-load-results/session-quick-test

./scripts/results-tools/analyze-session.sh \
  --session-dir ./variable-load-results/session-quick-test
```

### Use Case 3: Long-Term Stability Testing

**Goal:** 24-hour test with multiple iterations

```bash
# Run 5 iterations of 24-hour test
for i in {1..5}; do
  ./scripts/run-variable-load-multi-phase.sh \
    --runtime quarkus3-jvm --scenario ootb \
    --session-id stability-test \
    --duration 24h
done

# Analyze variability
./scripts/results-tools/analyze-session.sh \
  --session-dir ./variable-load-results/session-stability-test
```

## Best Practices

### Number of Iterations

- **Quick tests (3m phases):** 3-5 iterations
- **Standard tests (4h):** 3 iterations minimum
- **Long tests (24h):** 2-3 iterations
- **Production validation:** 5+ iterations

### Session Naming

Use descriptive session IDs:

```bash
# Recommended format
--session-id baseline-jdk17
--session-id tuned-jdk21
--session-id production-config

# Avoid
--session-id test1
--session-id run2
```

### Consistency Checks

Always check variability before comparing:

```bash
# 1. Run iterations
# 2. Aggregate
./scripts/results-tools/aggregate-session.sh --session-dir <dir>

# 3. Check consistency
./scripts/results-tools/analyze-session.sh --session-dir <dir>

# 4. If CV > 20%, consider running more iterations
# 5. Only then compare sessions
```

### Understanding CV (Coefficient of Variation)

CV% represents the ratio of standard deviation to mean, expressed as a percentage:
- **Lower CV%** = More consistent results across iterations
- **Higher CV%** = More variability between iterations

**General Guidelines:**
- **CV < 5%:** Very low variability - results are highly consistent
- **CV 5-10%:** Low variability - results show good repeatability
- **CV 10-20%:** Moderate variability - consider running more iterations
- **CV > 20%:** High variability - investigate causes or run more iterations

**Note:** These are general reference points. The acceptable CV% depends on your specific use case, metric type, and testing goals.

### Phase Duration Selection

| Duration Mode | Use Case | Total Time | Iterations Recommended |
|--------------|----------|------------|----------------------|
| `custom --phase-duration 3m` | Development/Debug | ~15 min | 3-5 |
| `1h` | Quick validation | ~1 hour | 3 |
| `4h` | Standard testing | ~4 hours | 3 |
| `24h` | Production simulation | ~24 hours | 2-3 |

### Disk Space Considerations

Each iteration generates:
- Phase logs (~10-50 MB per phase)
- JSON results (~1-5 MB)
- Metadata files (~1 KB)

**Example:** 5 phases × 3 iterations × 20 MB = ~300 MB per session

## Troubleshooting

### Issue: Iteration not auto-detected

**Symptom:** Script creates iteration 1 again instead of incrementing

**Solution:** Check that you're using the same `--session-id` and that files match the pattern `*-iter*.json`

### Issue: Aggregation fails

**Symptom:** `aggregate-session.sh` reports no iteration files found

**Solution:** 
1. Check that JSON files exist in session directory
2. Verify files match pattern: `<runtime>-<scenario>-iter<N>.json`
3. Ensure `run-variable-load-multi-phase.sh` completed successfully

### Issue: High variability (CV > 20%)

**Symptom:** `analyze-session.sh` shows poor consistency

**Solutions:**
1. Run more iterations (5-10)
2. Check for external factors (network issues, resource contention)
3. Increase phase duration for more stable measurements
4. Verify system is idle during tests

### Issue: Comparison shows unexpected results

**Symptom:** Session B shows regression instead of improvement

**Solutions:**
1. Check that both sessions have similar iteration counts
2. Verify both used same duration mode and phase settings
3. Review individual iteration files for anomalies
4. Check variability analysis for both sessions

## Advanced Usage

### Custom Iteration Numbers

```bash
# Explicitly specify iteration
./scripts/run-variable-load-multi-phase.sh \
  --runtime quarkus3-jvm --scenario ootb \
  --session-id baseline --iteration 5
```

### JSON Output for Automation

```bash
# Generate JSON comparison
./scripts/results-tools/compare-sessions.sh \
  --session-a ./variable-load-results/session-baseline \
  --session-b ./variable-load-results/session-optimized \
  --format json --output comparison.json

# Generate JSON variability analysis
./scripts/results-tools/analyze-session.sh \
  --session-dir ./variable-load-results/session-baseline \
  --format json --output variability.json
```

### Scripted Workflow

```bash
#!/bin/bash
# automated-comparison.sh

RUNTIME="quarkus3-jvm"
ITERATIONS=3

# Run baseline
for i in $(seq 1 $ITERATIONS); do
  ./scripts/run-variable-load-multi-phase.sh \
    --runtime $RUNTIME --scenario ootb \
    --session-id baseline --duration 4h
done

# Run optimized
for i in $(seq 1 $ITERATIONS); do
  ./scripts/run-variable-load-multi-phase.sh \
    --runtime $RUNTIME --scenario tuned \
    --session-id optimized --duration 4h
done

# Aggregate
./scripts/results-tools/aggregate-session.sh \
  --session-dir ./variable-load-results/session-baseline

./scripts/results-tools/aggregate-session.sh \
  --session-dir ./variable-load-results/session-optimized

# Compare
./scripts/results-tools/compare-sessions.sh \
  --session-a ./variable-load-results/session-baseline \
  --session-b ./variable-load-results/session-optimized \
  --output comparison-report.txt

echo "Comparison complete! See comparison-report.txt"
```

## Summary

The session-based testing framework provides:

1. **Automatic iteration tracking** - No manual numbering needed
2. **Statistical aggregation** - Mean, median, stddev across iterations
3. **Cross-session comparison** - Compare different configurations
4. **Variability analysis** - Measure test consistency
5. **Phase-level insights** - Understand performance at each load level

This enables reliable, reproducible performance testing with confidence in the results.