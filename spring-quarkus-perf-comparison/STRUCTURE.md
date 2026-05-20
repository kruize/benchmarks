# Benchmarks Git Repository Structure

This document describes the structure and contents of the benchmarks_git repository.

## Directory Structure

```
benchmarks_git/
├── README.md                          # Main documentation
├── STRUCTURE.md                       # This file
├── run-benchmark.sh                   # Main benchmark orchestration script
├── config.env                         # Main configuration file
├── image-build/                       # Container image building
│   ├── build-all-images.sh           # Build script for all images
│   ├── config.env                    # Configuration for image builds
│   └── dockerfiles/                  # Dockerfiles directory
│       ├── apps/                     # Application Dockerfiles
│       │   ├── Dockerfile.quarkus3-jvm
│       │   ├── Dockerfile.quarkus3-spring-compat
│       │   ├── Dockerfile.quarkus3-virtual
│       │   ├── Dockerfile.spring3-jvm
│       │   └── Dockerfile.spring4-jvm
│       └── postgres/                 # PostgreSQL Dockerfiles
│           ├── Dockerfile.postgres-fruits
│           └── create-postgres-data.sql
├── manifests/                         # Kubernetes/OpenShift manifests
│   ├── app-template.yaml             # Application deployment template (includes ServiceMonitor)
│   ├── postgresql.yaml               # PostgreSQL database
│   ├── fixed-load-hf.yml                 # Hyperfoil fixed load test benchmark
│   ├── variable-load-4h.hf.yml       # 4-hour variable load test benchmark
│   └── variable-load-24h.hf.yml      # 24-hour variable load test benchmark
└── scripts/                           # Deployment, testing, and analysis scripts
    ├── deploy-app.sh                 # Deploy applications
    ├── measure-startup.sh            # Measure application startup time
    ├── measure-memory.sh             # Measure memory usage (RSS)
    ├── run-load-test.sh              # Run load tests
    ├── run-variable-load-multi-phase.sh # Multi-phase variable load test
    └── results-tools/                # Results analysis tools
        ├── compare-all.sh            # Compare all runtimes and scenarios
        ├── compare-results.sh        # Compare specific results
        └── generate-report.sh        # Generate HTML reports
```

## Source Mapping

### From `docs/benchmark-images/`
- `build-all-images.sh` → `image-build/build-all-images.sh`
- `config.env` → `image-build/config.env`
- `dockerfiles/Dockerfile.quarkus*` → `image-build/dockerfiles/apps/`
- `dockerfiles/Dockerfile.spring*` → `image-build/dockerfiles/apps/`
- `dockerfiles/Dockerfile.postgres-fruits` → `image-build/dockerfiles/postgres/`
- `dockerfiles/create-postgres-data.sql` → `image-build/dockerfiles/postgres/`

### From `docs/openshift-benchmark/`
- `config.env` → `config.env` (top level)
- `manifests/app-template.yaml` → `manifests/app-template.yaml`
- `manifests/postgresql.yaml` → `manifests/postgresql.yaml`
- `scripts/deploy-app.sh` → `scripts/deploy-app.sh`
- `scripts/measure-*.sh` → `scripts/measure-*.sh`
- `scripts/run-load-test.sh` → `scripts/run-load-test.sh`
- `scripts/run-variable-load-multi-phase.sh` → `scripts/run-variable-load-multi-phase.sh`
- `run-benchmark.sh` → `run-benchmark.sh` (top level)
- `results-tools/*` → `scripts/results-tools/*`

## File Counts

- **Top Level:**
  - 1 main benchmark script
  - 1 main config file
  - 2 documentation files

- **Image Build:**
  - 1 build script
  - 1 config file
  - 5 application Dockerfiles
  - 1 PostgreSQL Dockerfile
  - 1 SQL initialization script

- **Manifests:**
  - 2 manifest files

- **Scripts:**
  - 5 deployment/testing scripts
  - 3 results analysis tools

**Total:** 24 files organized for the kruize/benchmarks repository

## Key Features

### Organized Dockerfiles
Dockerfiles are organized by purpose:
- `dockerfiles/apps/` - Application images (Quarkus, Spring Boot variants)
- `dockerfiles/postgres/` - PostgreSQL database with initialization

### End-to-End Benchmarking
The `run-benchmark.sh` script orchestrates complete benchmark workflows:
- Deploys applications with different configurations
- Runs multiple test types (startup, memory, load)
- Supports multiple iterations for statistical significance
- Generates comprehensive metrics and reports
- Compares performance across runtimes and scenarios

### Multi-Phase Variable Load Testing
Uses `run-variable-load-multi-phase.sh` for realistic workload simulation:
- Multiple phases with different load intensities
- Configurable duration and thread counts
- Supports both read and write operations
- Generates metrics for Kruize analysis

### PostgreSQL Database
Standard PostgreSQL deployment used by benchmark applications:
- `postgresql.yaml` - PostgreSQL database for data persistence

### Results Analysis
Comprehensive analysis tools in `scripts/results-tools/`:
- Compare all runtimes and scenarios
- Generate detailed comparison reports
- Create HTML reports for visualization

## Dependencies

The `run-benchmark.sh` script requires:
- OpenShift CLI (`oc`)
- `jq` for JSON processing
- JBang (for load testing)
- All manifests in `manifests/`
- All scripts in `scripts/`
- Results analysis tools in `scripts/results-tools/`

## Usage

See [README.md](README.md) for detailed usage instructions.