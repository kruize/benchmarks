# Spring-Quarkus-Perf-Comparison Benchmark

This repository contains benchmark tools and configurations for testing Kruize with various application frameworks.

> **Note:** For detailed repository structure and file organization, see [STRUCTURE.md](STRUCTURE.md)


## Prerequisites

- Kubernetes or OpenShift cluster
- `kubectl` or `oc` CLI tools
- JBang (for running load tests) - **auto-installed if not present**
- `jq` for JSON processing


### 1. Main Benchmark Script (`run-benchmark.sh`)

The main orchestration script that runs complete end-to-end benchmarks. It handles everything automatically:
- Sets up OpenShift project
- Deploys PostgreSQL database
- Deploys applications with different configurations (JAVA_OPTS based on scenario)
- Runs multiple test types (startup, memory, load)
- Runs the benchmark at a fixed load for 30s.
- Supports multiple iterations for statistical significance
- Generates comprehensive metrics and reports
- Compares performance across runtimes and scenarios
- Optionally cleans up deployments after tests

**Note:** JAVA_OPTS are configured in `config.env` based on the selected scenario:
- `ootb` scenario uses `JAVA_OPTS_OOTB` from config.env
- `tuned` scenario uses `JAVA_OPTS_TUNED` from config.env (can be replaced with Kruize recommendations)

**Usage:**
```bash
./run-benchmark.sh [OPTIONS]
```

**Options:**
```
--scenario <SCENARIO>       Scenario: ootb (default) or tuned
--runtimes <RUNTIMES>       Comma-separated list of runtimes
--tests <TESTS>             Comma-separated list of tests
--iterations <N>            Number of iterations (default: 3)
--output-dir <DIR>          Output directory for results
--registry <REGISTRY>       Container registry
--image-tag <TAG>           Image tag
--project <PROJECT>         OpenShift project name
--cleanup                   Cleanup after tests
--no-cleanup                Don't cleanup after tests
--help                      Show help message
```

**Available Runtimes:**
- `quarkus3-jvm` - Quarkus 3 with standard JVM
- `quarkus3-virtual` - Quarkus 3 with Virtual Threads
- `spring3-jvm` - Spring Boot 3 with standard JVM
- `spring4-jvm` - Spring Boot 4 with standard JVM

**Available Tests:**
- `measure-startup` - Measure application startup time
- `measure-memory` - Measure memory usage (RSS)
- `run-load-test` - Run load test using JBang

**Available Scenarios:**
- `ootb` - Out-of-the-box (default JVM settings)
- `tuned` - Tuned (optimized JVM settings)

**Examples:**
```bash
# Run default configuration
./run-benchmark.sh

# Run specific scenario and runtimes
./run-benchmark.sh --scenario tuned --runtimes quarkus3-jvm,spring4-jvm

# Run with custom iterations
./run-benchmark.sh --iterations 5 --tests run-load-test

# Run without cleanup
./run-benchmark.sh --no-cleanup
```

### 2. Multi-Phase Load Performance Test (`scripts/perf`)

Run the performance comparison for multiple scenarios  for a runtime.
```bash
# Run default configuration ((Compares OOTB vs Tuned for quarkus3-jvm))
perf-test-ootb-vs-tuned.sh
```

This workflow simulates fluid, real-world patterns with a multi-phase variable load testing approach featuring:

- **Dynamic Workloads**: Multiple phases with shifting load intensities, thread counts, and durations.
- **Session-Based Iteration Tracking**: Run tests repeatedly with auto-incrementing iteration tracking.
- **Advanced Analytics**: Statistical aggregation calculates mean, median, standard deviation, and consistency metrics (Coefficient of Variation) to detect test drift.
- **Phase-Level Cross-Session Insights**: Directly compare OOTB vs Tuned configurations phase-by-phase.

**For detailed documentation on running variable load, see [VARIABLE_LOAD_SESSION_GUIDE.md](VARIABLE_LOAD_SESSION_GUIDE.md)**


### 3. Image Build (`image-build/`)

Contains Dockerfiles and scripts to build benchmark application images with Micrometer Prometheus metrics enabled for Kruize analysis.

> **Note:** For detailed image building instructions, see [image-build/README.md](image-build/README.md)


## Components

### Manifests (`manifests/`)

Kubernetes/OpenShift deployment manifests:
- `app-template.yaml` - Application deployment template (includes ServiceMonitor)
- `postgresql.yaml` - PostgreSQL database deployment

###  Scripts (`scripts/`)

Deployment, testing, and analysis scripts:

**Deployment:**
- `deploy-app.sh` - Deploy benchmark applications

**Testing:**
- `run-variable-load-multi-phase.sh` - Run multi-phase variable load tests with session-based iteration tracking
- `measure-startup.sh` - Measure application startup time
- `measure-memory.sh` - Measure memory usage (RSS)
- `run-load-test.sh` - Run load tests
- `common-utils.sh` - Shared utility functions for all scripts

**Analysis:**
- `results-tools/compare-all.sh` - Compare all runtimes and scenarios (text output)
- `results-tools/generate-report.sh` - Generate interactive HTML reports with scenario and runtime comparisons
- `results-tools/aggregate-session.sh` - Aggregate metrics across multiple iterations within a session
- `results-tools/compare-sessions.sh` - Compare two sessions phase-by-phase (e.g., OOTB vs Tuned)
- `results-tools/analyze-session.sh` - Analyze within-session variability and consistency
