#!/bin/bash
################################################################################
# Application Deployment Script
#
# Deploys application and PostgreSQL database to OpenShift
# Outputs the application endpoint URL for use with load testing
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} [INFO] $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} [SUCCESS] $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} [ERROR] $*"
}

# Default configuration
RUNTIME="quarkus3-jvm"
SCENARIO="ootb"
NAMESPACE="quarkus-perf-benchmark"
IMAGE=""
CONTAINER_NAME="app"
JAVA_OPTS=""

# Default resource requests and limits
CPU_REQUEST="500m"
CPU_LIMIT="3000m"
MEMORY_REQUEST="512Mi"
MEMORY_LIMIT="2Gi"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy application and database to OpenShift for benchmarking.

Options:
  --runtime RUNTIME      Runtime to deploy (default: ${RUNTIME})
                         Options: quarkus3-jvm, quarkus3-virtual, quarkus3-spring-compat,
                                  spring3-jvm, spring3-virtual, spring4-jvm, spring4-virtual
  --scenario SCENARIO    Deployment scenario (default: ${SCENARIO})
                          Common options: ootb (out-of-the-box), tuned (optimized)
                          Can be any custom name when using --java-opts
  --namespace NS         OpenShift namespace (default: ${NAMESPACE})
  --image IMAGE          Container image (optional, uses config.env if not specified)
  --container-name NAME  Container name (default: ${CONTAINER_NAME})
  --java-opts OPTS       Custom JAVA_OPTS (optional, uses scenario defaults)
  
  Resource Configuration:
  --cpu-request CPU      CPU request (default: ${CPU_REQUEST})
  --cpu-limit CPU        CPU limit (default: ${CPU_LIMIT})
  --memory-request MEM   Memory request (default: ${MEMORY_REQUEST})
  --memory-limit MEM     Memory limit (default: ${MEMORY_LIMIT})
  
  --help, -h             Show this help message

Examples:
  # Deploy quarkus3-jvm with OOTB settings
  $0 --runtime quarkus3-jvm --scenario ootb

  # Deploy spring4-virtual with tuned settings
  $0 --runtime spring4-virtual --scenario tuned

  # Deploy with custom image
  $0 --runtime quarkus3-jvm --image quay.io/myuser/quarkus3-jvm:v1.0

  # Deploy with custom JAVA_OPTS and scenario name
  $0 --runtime quarkus3-jvm --scenario custom --java-opts "-Xmx1g -Xms512m -XX:+UseG1GC"

  # Deploy with custom resource limits
  $0 --runtime quarkus3-jvm --cpu-limit 4000m --memory-limit 4Gi

  # Deploy with Kruize recommendations
  $0 --runtime quarkus3-jvm --scenario tuned --cpu-request 750m --cpu-limit 2500m \\
     --memory-request 768Mi --memory-limit 1536Mi --java-opts "-Xmx1200m -Xms768m"

EOF
    exit 0
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --runtime)
                RUNTIME="$2"
                shift 2
                ;;
            --scenario)
                SCENARIO="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --image)
                IMAGE="$2"
                shift 2
                ;;
            --container-name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            --java-opts)
                JAVA_OPTS="$2"
                shift 2
                ;;
            --cpu-request)
                CPU_REQUEST="$2"
                shift 2
                ;;
            --cpu-limit)
                CPU_LIMIT="$2"
                shift 2
                ;;
            --memory-request)
                MEMORY_REQUEST="$2"
                shift 2
                ;;
            --memory-limit)
                MEMORY_LIMIT="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Get image name from config
get_image_name_from_config() {
    if [ -n "$IMAGE" ]; then
        echo "$IMAGE"
        return
    fi
    
    # Try to load from config.env
    local config_file="${SCRIPT_DIR}/../config.env"
    if [ -f "$config_file" ]; then
        source "$config_file"
        
        # Use the helper function from config.env
        if type get_image_name &>/dev/null; then
            get_image_name "$RUNTIME"
        else
            log_error "get_image_name function not found in config.env"
            echo ""
        fi
    else
        log_error "Config file not found: $config_file"
        echo ""
    fi
}

# Get JAVA_OPTS based on scenario
get_java_opts_from_config() {
    if [ -n "$JAVA_OPTS" ]; then
        echo "$JAVA_OPTS"
        return
    fi
    
    # Try to load from config.env
    local config_file="${SCRIPT_DIR}/../config.env"
    if [ -f "$config_file" ]; then
        source "$config_file"
        
        # Use the helper function from config.env
        if type get_java_opts &>/dev/null; then
            local opts=$(get_java_opts "$SCENARIO")
            # If function returns empty for custom scenario, that's OK
            echo "$opts"
        else
            # Fallback to defaults for known scenarios
            case "$SCENARIO" in
                ootb)
                    echo "$JAVA_OPTS_OOTB"
                    ;;
                tuned)
                    echo "$JAVA_OPTS_TUNED"
                    ;;
                *)
                    # For custom scenarios, return empty (user should provide --java-opts)
                    echo ""
                    ;;
            esac
        fi
    else
        # Fallback defaults if config not found
        case "$SCENARIO" in
            ootb)
                echo ""
                ;;
            tuned)
                echo "-Xmx512m -Xms512m -XX:+UseParallelGC -XX:+UseNUMA"
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

# Get resource configuration based on scenario
get_resources_from_config() {
    local scenario_upper=$(echo "$SCENARIO" | tr '[:lower:]' '[:upper:]')
    
    # Try to load from config.env
    local config_file="${SCRIPT_DIR}/../config.env"
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi
    
    # Set resources based on scenario, with fallback to defaults
    case "$SCENARIO" in
        ootb)
            CPU_REQUEST="${CPU_REQUEST_OOTB:-${CPU_REQUEST}}"
            CPU_LIMIT="${CPU_LIMIT_OOTB:-${CPU_LIMIT}}"
            MEMORY_REQUEST="${MEMORY_REQUEST_OOTB:-${MEMORY_REQUEST}}"
            MEMORY_LIMIT="${MEMORY_LIMIT_OOTB:-${MEMORY_LIMIT}}"
            ;;
        tuned)
            CPU_REQUEST="${CPU_REQUEST_TUNED:-${CPU_REQUEST}}"
            CPU_LIMIT="${CPU_LIMIT_TUNED:-${CPU_LIMIT}}"
            MEMORY_REQUEST="${MEMORY_REQUEST_TUNED:-${MEMORY_REQUEST}}"
            MEMORY_LIMIT="${MEMORY_LIMIT_TUNED:-${MEMORY_LIMIT}}"
            ;;
        *)
            # For custom scenarios, use defaults or command-line provided values
            # (already set in global variables)
            ;;
    esac
}

# Deploy PostgreSQL
deploy_postgresql() {
    log_info "Deploying PostgreSQL database..."
    
    if oc get deployment postgresql -n "${NAMESPACE}" &> /dev/null; then
        log_info "PostgreSQL already deployed"
        return 0
    fi
    
    local manifest_file="${SCRIPT_DIR}/../manifests/postgresql.yaml"
    if [ ! -f "$manifest_file" ]; then
        log_error "PostgreSQL manifest not found: $manifest_file"
        return 1
    fi
    
    oc apply -f "$manifest_file" -n "${NAMESPACE}"
    
    log_info "Waiting for PostgreSQL to be ready..."
    if ! oc wait --for=condition=available --timeout=300s deployment/postgresql -n "${NAMESPACE}"; then
        log_error "PostgreSQL deployment failed"
        return 1
    fi
    
    log_success "PostgreSQL deployed successfully"
}

# Deploy application
deploy_application() {
    local image=$(get_image_name_from_config)
    local java_opts=$(get_java_opts_from_config)
    
    # Get scenario-specific resources (updates global variables)
    get_resources_from_config
    
    if [ -z "$image" ]; then
        log_error "Could not determine image for runtime: $RUNTIME"
        log_error "Please specify --image or ensure config.env is properly configured"
        return 1
    fi
    
    # Determine metrics path based on runtime
    local metrics_path
    case "$RUNTIME" in
        quarkus*|quarkus3-spring-compat)
            metrics_path="/q/metrics"
            ;;
        spring*)
            metrics_path="/actuator/prometheus"
            ;;
        *)
            metrics_path="/q/metrics"  # Default to Quarkus
            ;;
    esac
    
    log_info "Deploying ${RUNTIME} with ${SCENARIO} scenario..."
    log_info "Image: ${image}"
    log_info "Container Name: ${CONTAINER_NAME}"
    if [ -n "$java_opts" ]; then
        log_info "JAVA_OPTS: ${java_opts}"
    else
        log_info "JAVA_OPTS: (none - using JVM defaults)"
    fi
    log_info "Metrics Path: ${metrics_path}"
    log_info "Resources:"
    log_info "  CPU Request: ${CPU_REQUEST}, Limit: ${CPU_LIMIT}"
    log_info "  Memory Request: ${MEMORY_REQUEST}, Limit: ${MEMORY_LIMIT}"
    
    local app_name="${RUNTIME}-${SCENARIO}"
    local manifest_file="${SCRIPT_DIR}/../manifests/app-template.yaml"
    
    if [ ! -f "$manifest_file" ]; then
        log_error "Application manifest not found: $manifest_file"
        return 1
    fi
    
    # Generate deployment manifest
    sed -e "s|{{RUNTIME}}|${RUNTIME}|g" \
        -e "s|{{SCENARIO}}|${SCENARIO}|g" \
        -e "s|{{IMAGE}}|${image}|g" \
        -e "s|{{CONTAINER_NAME}}|${CONTAINER_NAME}|g" \
        -e "s|{{JAVA_OPTS}}|${java_opts}|g" \
        -e "s|{{CPU_REQ}}|${CPU_REQUEST}|g" \
        -e "s|{{CPU_LIM}}|${CPU_LIMIT}|g" \
        -e "s|{{MEM_REQ}}|${MEMORY_REQUEST}|g" \
        -e "s|{{MEM_LIM}}|${MEMORY_LIMIT}|g" \
        -e "s|{{METRICS_PATH}}|${metrics_path}|g" \
        "$manifest_file" | oc apply -n "${NAMESPACE}" -f -
    
    log_info "Waiting for ${app_name} to be ready..."
    if ! oc wait --for=condition=available --timeout=300s deployment/${app_name} -n "${NAMESPACE}"; then
        log_error "Application deployment failed"
        return 1
    fi
    
    log_success "Application deployed successfully"
}

# Get application endpoint
get_endpoint() {
    local app_name="${RUNTIME}-${SCENARIO}"
    
    log_info "Getting application endpoint..."
    
    # Try to get route first (OpenShift)
    local route_host=$(oc get route ${app_name} -n ${NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    
    if [ -n "$route_host" ]; then
        echo "http://${route_host}"
        return 0
    fi
    
    # Fallback to service ClusterIP
    local service_ip=$(oc get svc ${app_name} -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    
    if [ -n "$service_ip" ]; then
        echo "http://${service_ip}:8080"
        return 0
    fi
    
    log_error "Could not determine application endpoint"
    return 1
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "=========================================="
    log_info "Application Deployment"
    log_info "=========================================="
    log_info "Runtime: ${RUNTIME}"
    log_info "Scenario: ${SCENARIO}"
    log_info "Namespace: ${NAMESPACE}"
    log_info "Resources: CPU ${CPU_REQUEST}/${CPU_LIMIT}, Memory ${MEMORY_REQUEST}/${MEMORY_LIMIT}"
    log_info "=========================================="
    
    # Check if logged in to OpenShift
    if ! oc whoami &> /dev/null; then
        log_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    
    # Create/use namespace
    if ! oc get project "${NAMESPACE}" &> /dev/null; then
        log_info "Creating namespace: ${NAMESPACE}"
        oc new-project "${NAMESPACE}"
    else
        log_info "Using existing namespace: ${NAMESPACE}"
        oc project "${NAMESPACE}"
    fi
    
    # Deploy PostgreSQL
    if ! deploy_postgresql; then
        log_error "PostgreSQL deployment failed"
        exit 1
    fi
    
    # Deploy application
    if ! deploy_application; then
        log_error "Application deployment failed"
        exit 1
    fi
    
    # Get endpoint
    local endpoint=$(get_endpoint)
    if [ $? -ne 0 ]; then
        log_error "Failed to get application endpoint"
        exit 1
    fi
    
    log_success "=========================================="
    log_success "Deployment Complete!"
    log_success "=========================================="
    log_success "Application: ${RUNTIME}-${SCENARIO}"
    log_success "Namespace: ${NAMESPACE}"
    log_success "Endpoint: ${endpoint}"
    log_success "=========================================="
    log_info ""
    log_info "To run variable load test, use:"
    log_info "./run-variable-load.sh --url ${endpoint} --runtime ${RUNTIME}"
    log_info ""
    log_info "To check application status:"
    log_info "oc get pods -n ${NAMESPACE}"
    log_info ""
    log_info "To view logs:"
    log_info "oc logs -f deployment/${RUNTIME}-${SCENARIO} -n ${NAMESPACE}"
}

main "$@"

# Made with Bob
