#!/bin/bash
################################################################################
# Main script to build all benchmark container images
# This script:
#   1. Clones the spring-quarkus-perf-comparison repository
#   2. Builds all 4 application variants (Quarkus JVM/Virtual, Spring JVM/Virtual)
#   3. Creates container images for each variant
#   4. Optionally pushes images to container registry
################################################################################

# Note: We don't use 'set -e' here because we want to continue building other images
# even if one fails. Each critical operation has its own error handling.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
else
    echo "ERROR: config.env not found!"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check for git
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    # Check for maven
    if ! command -v mvn &> /dev/null; then
        missing_tools+=("maven")
    fi
    
    # Check for podman or docker
    if command -v podman &> /dev/null; then
        CONTAINER_CMD="podman"
        print_info "Using podman for container builds"
    elif command -v docker &> /dev/null; then
        CONTAINER_CMD="docker"
        print_info "Using docker for container builds"
    else
        missing_tools+=("podman or docker")
    fi
    
    # Check Java version
    if ! command -v java &> /dev/null; then
        missing_tools+=("java")
    else
        print_info "Java version: $(java -version 2>&1 | head -n 1)"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools:"
        echo "  - git: https://git-scm.com/downloads"
        echo "  - maven: https://maven.apache.org/download.cgi"
        echo "  - podman: https://podman.io/getting-started/installation"
        echo "  - java: Use SDKMAN (https://sdkman.io/)"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to clone repository if needed
clone_repository() {
    print_step "Cloning Repository"
    
    if [ -d "${REPO_DIR}" ]; then
        print_info "Repository already exists at ${REPO_DIR}"
        read -p "Do you want to pull latest changes? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "${REPO_DIR}"
            git pull
            cd "${SCRIPT_DIR}"
            print_success "Repository updated"
        fi
    else
        print_info "Cloning repository from ${REPO_URL}..."
        git clone "${REPO_URL}" "${REPO_DIR}"
        print_success "Repository cloned to ${REPO_DIR}"
    fi
}

# Function to add Prometheus Micrometer dependencies to Quarkus pom.xml
add_quarkus_micrometer_deps() {
    local pom_file=$1
    local app_name=$2
    
    print_info "Adding Prometheus Micrometer dependencies to ${app_name}..."
    
    # Check if dependencies already exist
    if grep -q "quarkus-micrometer-registry-prometheus" "${pom_file}"; then
        print_info "Prometheus Micrometer dependencies already present in ${app_name}"
        return 0
    fi
    
    # Create backup
    cp "${pom_file}" "${pom_file}.backup"
    
    # Find the </dependencies> tag within main <dependencies> section (not in <dependencyManagement>)
    # and add our dependencies BEFORE it
    # Use awk to ensure we're adding to the right <dependencies> section
    awk '
    /<dependencyManagement>/ { in_dep_mgmt=1 }
    /<\/dependencyManagement>/ { in_dep_mgmt=0 }
    /<dependencies>/ && !in_dep_mgmt { in_deps=1 }
    {
        if (/<\/dependencies>/ && in_deps && !in_dep_mgmt) {
            # Insert BEFORE </dependencies> closing tag
            print "        <!-- Micrometer Prometheus Registry -->"
            print "        <dependency>"
            print "            <groupId>io.quarkus</groupId>"
            print "            <artifactId>quarkus-micrometer</artifactId>"
            print "        </dependency>"
            print "        <dependency>"
            print "            <groupId>io.quarkus</groupId>"
            print "            <artifactId>quarkus-micrometer-registry-prometheus</artifactId>"
            print "        </dependency>"
            in_deps=0
        }
        print
    }
    ' "${pom_file}.backup" > "${pom_file}"
    
    if [ $? -eq 0 ]; then
        print_success "Added Prometheus Micrometer dependencies to ${app_name}"
        rm "${pom_file}.backup"
    else
        print_error "Failed to add dependencies to ${app_name}"
        mv "${pom_file}.backup" "${pom_file}"
        return 1
    fi
}

# Function to add Prometheus Micrometer configuration to Quarkus application config
add_quarkus_micrometer_config() {
    local config_dir=$1
    local app_name=$2
    
    print_info "Adding Prometheus Micrometer configuration to ${app_name}..."
    
    # Check for YAML or properties file
    local config_file=""
    if [ -f "${config_dir}/application.yml" ]; then
        config_file="${config_dir}/application.yml"
    elif [ -f "${config_dir}/application.yaml" ]; then
        config_file="${config_dir}/application.yaml"
    elif [ -f "${config_dir}/application.properties" ]; then
        config_file="${config_dir}/application.properties"
    else
        print_warning "No configuration file found in ${config_dir}, skipping Micrometer config"
        return 0
    fi
    
    # Check if configuration already exists
    if grep -q "micrometer" "${config_file}"; then
        print_info "Micrometer configuration already present in ${app_name}"
        return 0
    fi
    
    # Create backup
    cp "${config_file}" "${config_file}.backup"
    
    # Add configuration based on file type
    if [[ "${config_file}" == *.yml ]] || [[ "${config_file}" == *.yaml ]]; then
        # Add YAML configuration
        cat >> "${config_file}" << 'EOF'

  # Micrometer Prometheus Configuration
  micrometer:
    enabled: true
    export:
      prometheus:
        enabled: true
        path: /q/metrics
    binder:
      jvm: true
      http-server:
        enabled: true
      http-client:
        enabled: true
      system: true
EOF
    else
        # Add properties configuration
        cat >> "${config_file}" << 'EOF'

# Micrometer Prometheus Configuration
quarkus.micrometer.enabled=true
quarkus.micrometer.export.prometheus.enabled=true
quarkus.micrometer.export.prometheus.path=/q/metrics

# Enable metric binders
quarkus.micrometer.binder.jvm=true
quarkus.micrometer.binder.http-server.enabled=true
quarkus.micrometer.binder.http-client.enabled=true
quarkus.micrometer.binder.system=true
EOF
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Added Prometheus Micrometer configuration to ${app_name}"
    else
        print_error "Failed to add configuration to ${app_name}"
        mv "${config_file}.backup" "${config_file}"
        return 1
    fi
}

# Function to add Spring Boot Actuator and Prometheus dependencies
add_spring_micrometer_deps() {
    local pom_file=$1
    local app_name=$2
    
    print_info "Adding Prometheus Micrometer dependencies to ${app_name}..."
    
    # Check if dependencies already exist
    if grep -q "micrometer-registry-prometheus" "${pom_file}"; then
        print_info "Prometheus Micrometer dependencies already present in ${app_name}"
        return 0
    fi
    
    # Create backup
    cp "${pom_file}" "${pom_file}.backup"
    
    # Add dependencies before </dependencies> closing tag
    sed -i '/<\/dependencies>/i\
        <!-- Spring Boot Actuator with Micrometer -->\
        <dependency>\
            <groupId>org.springframework.boot</groupId>\
            <artifactId>spring-boot-starter-actuator</artifactId>\
        </dependency>\
        <dependency>\
            <groupId>io.micrometer</groupId>\
            <artifactId>micrometer-registry-prometheus</artifactId>\
        </dependency>' "${pom_file}"
    
    if [ $? -eq 0 ]; then
        print_success "Added Prometheus Micrometer dependencies to ${app_name}"
    else
        print_error "Failed to add dependencies to ${app_name}"
        mv "${pom_file}.backup" "${pom_file}"
        return 1
    fi
}

# Function to add Spring Boot Actuator configuration
add_spring_micrometer_config() {
    local props_file=$1
    local app_name=$2
    
    print_info "Adding Prometheus Micrometer configuration to ${app_name}..."
    
    # Check if configuration already exists
    if grep -q "management.endpoints.web.exposure.include" "${props_file}"; then
        print_info "Prometheus Micrometer configuration already present in ${app_name}"
        return 0
    fi
    
    # Create backup
    cp "${props_file}" "${props_file}.backup"
    
    # Add configuration
    cat >> "${props_file}" << 'EOF'

# Spring Boot Actuator Configuration
management.endpoints.web.exposure.include=health,info,metrics,prometheus
management.endpoints.web.base-path=/actuator
management.endpoint.prometheus.enabled=true
management.metrics.enable.jvm=true
management.metrics.enable.process=true
management.metrics.enable.system=true
management.metrics.enable.http=true
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Added Prometheus Micrometer configuration to ${app_name}"
    else
        print_error "Failed to add configuration to ${app_name}"
        mv "${props_file}.backup" "${props_file}"
        return 1
    fi
}

# Function to build application JAR
build_application() {
    local app_dir=$1
    local app_name=$2
    local app_type=$3  # "quarkus" or "spring"
    
    print_info "Building ${app_name}..."
    
    # Check if directory exists
    if [ ! -d "${REPO_DIR}/${app_dir}" ]; then
        print_warning "Directory ${REPO_DIR}/${app_dir} not found, skipping ${app_name}"
        return 1
    fi
    
    cd "${REPO_DIR}/${app_dir}" || {
        print_error "Failed to change to directory ${REPO_DIR}/${app_dir}"
        return 1
    }
    
    # Add Prometheus Micrometer support
    if [ "${app_type}" = "quarkus" ]; then
        add_quarkus_micrometer_deps "pom.xml" "${app_name}"
        add_quarkus_micrometer_config "src/main/resources" "${app_name}"
    elif [ "${app_type}" = "spring" ]; then
        add_spring_micrometer_deps "pom.xml" "${app_name}"
        if [ -f "src/main/resources/application.properties" ]; then
            add_spring_micrometer_config "src/main/resources/application.properties" "${app_name}"
        fi
    fi
    
    # Build the application
    if [ "${SKIP_TESTS}" = "true" ]; then
        mvn clean package -DskipTests
    else
        mvn clean package
    fi
    
    if [ $? -eq 0 ]; then
        print_success "${app_name} built successfully"
        cd "${SCRIPT_DIR}"
        return 0
    else
        print_error "Failed to build ${app_name}"
        cd "${SCRIPT_DIR}"
        return 1
    fi
}

# Function to build container image
build_image() {
    local dockerfile=$1
    local context_dir=$2
    local image_name=$3
    local app_name=$4
    
    print_info "Building container image for ${app_name}..."
    
    # Check if context directory exists
    if [ ! -d "${context_dir}" ]; then
        print_warning "Context directory ${context_dir} not found, skipping ${app_name} image build"
        return 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "${SCRIPT_DIR}/dockerfiles/${dockerfile}" ]; then
        print_warning "Dockerfile ${SCRIPT_DIR}/dockerfiles/${dockerfile} not found, skipping ${app_name} image build"
        return 1
    fi
    
    ${CONTAINER_CMD} build \
        -f "${SCRIPT_DIR}/dockerfiles/${dockerfile}" \
        -t "${image_name}" \
        "${context_dir}"
    
    if [ $? -eq 0 ]; then
        print_success "Image ${image_name} built successfully"
        return 0
    else
        print_error "Failed to build image ${image_name}"
        return 1
    fi
}

# Function to push image to registry
push_image() {
    local image_name=$1
    
    print_info "Pushing ${image_name} to registry..."
    
    ${CONTAINER_CMD} push "${image_name}"
    
    if [ $? -eq 0 ]; then
        print_success "Image ${image_name} pushed successfully"
    else
        print_error "Failed to push image ${image_name}"
        return 1
    fi
}

# Function to list built images
list_images() {
    print_step "Built Images"
    ${CONTAINER_CMD} images | head -n 1
    ${CONTAINER_CMD} images | grep -E "(quarkus3|spring3|spring4)" | grep "${REGISTRY_USER}" || echo "No images found"
}

# Main execution
main() {
    echo "========================================================================"
    echo "  Spring-Quarkus Performance Benchmark - Image Builder"
    echo "========================================================================"
    echo ""
    
    # Parse command line arguments
    SELECTED_RUNTIMES=("$@")
    
    # Show usage if --help is specified
    if [[ " ${SELECTED_RUNTIMES[@]} " =~ " --help " ]] || [[ " ${SELECTED_RUNTIMES[@]} " =~ " -h " ]]; then
        cat << EOF
Usage: $0 [RUNTIMES...]

Build container images for Spring-Quarkus performance benchmarks.
All images include Prometheus Micrometer support for metrics collection.

Arguments:
  RUNTIMES    Optional. Specify which runtimes to build (space-separated).
              If not specified, builds all runtimes.
              
Available runtimes:
  quarkus3-jvm           Quarkus 3 with standard JVM
  quarkus3-virtual       Quarkus 3 with Virtual Threads
  quarkus3-spring-compat Quarkus 3 with Spring API compatibility
  spring3-jvm            Spring Boot 3 with standard JVM
  spring4-jvm            Spring Boot 4 with standard JVM
  all                    Build all runtimes (default)

Examples:
  # Build all runtimes
  $0
  $0 all
  
  # Build only Quarkus JVM
  $0 quarkus3-jvm
  
  # Build Quarkus with Spring compatibility
  $0 quarkus3-spring-compat
  
  # Build multiple specific runtimes
  $0 quarkus3-jvm spring4-jvm
  
  # Build all Quarkus variants
  $0 quarkus3-jvm quarkus3-virtual quarkus3-spring-compat
  
  # Build all Spring Boot variants
  $0 spring3-jvm spring4-jvm

EOF
        exit 0
    fi
    
    # Display selected runtimes
    if [ ${#SELECTED_RUNTIMES[@]} -eq 0 ]; then
        print_info "Building all runtimes (default)"
        SELECTED_RUNTIMES=("all")
    else
        print_info "Selected runtimes: ${SELECTED_RUNTIMES[*]}"
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Clone repository
    clone_repository
    
    # Build applications
    print_step "Step 1: Building Applications (with Prometheus Micrometer)"
    
    local build_quarkus3=false
    local build_quarkus3_virtual=false
    local build_quarkus3_spring_compat=false
    local build_spring3=false
    local build_spring4=false
    
    # Determine what needs to be built
    for runtime in "${SELECTED_RUNTIMES[@]}"; do
        case "$runtime" in
            all)
                build_quarkus3=true
                build_quarkus3_virtual=true
                build_quarkus3_spring_compat=true
                build_spring3=true
                build_spring4=true
                ;;
            quarkus3-jvm)
                build_quarkus3=true
                ;;
            quarkus3-virtual)
                build_quarkus3_virtual=true
                ;;
            quarkus3-spring-compat)
                build_quarkus3_spring_compat=true
                ;;
            spring3-jvm)
                build_spring3=true
                ;;
            spring4-jvm)
                build_spring4=true
                ;;
            *)
                print_warning "Unknown runtime: $runtime"
                ;;
        esac
    done
    
    # Build applications
    if [ "$build_quarkus3" = true ]; then
        build_application "quarkus3" "Quarkus 3 JVM" "quarkus"
    fi
    
    if [ "$build_quarkus3_virtual" = true ]; then
        build_application "quarkus3-virtual" "Quarkus 3 Virtual Threads" "quarkus"
    fi
    
    if [ "$build_quarkus3_spring_compat" = true ]; then
        build_application "quarkus3-spring-compatibility" "Quarkus 3 Spring Compatibility" "quarkus"
    fi
    
    if [ "$build_spring3" = true ]; then
        build_application "springboot3" "Spring Boot 3" "spring"
    fi
    
    if [ "$build_spring4" = true ]; then
        build_application "springboot4" "Spring Boot 4" "spring"
    fi
    
    # Build container images
    print_step "Step 2: Building Container Images"
    
    local images_built=0
    
    for runtime in "${SELECTED_RUNTIMES[@]}"; do
        case "$runtime" in
            all)
                if build_image "apps/Dockerfile.quarkus3-jvm" "${REPO_DIR}/quarkus3" "${QUARKUS3_JVM_IMAGE}" "Quarkus 3 JVM"; then
                    ((images_built++))
                fi
                if build_image "apps/Dockerfile.quarkus3-virtual" "${REPO_DIR}/quarkus3-virtual" "${QUARKUS3_VIRTUAL_IMAGE}" "Quarkus 3 Virtual"; then
                    ((images_built++))
                fi
                if build_image "apps/Dockerfile.quarkus3-spring-compat" "${REPO_DIR}/quarkus3-spring-compatibility" "${QUARKUS3_SPRING_COMPAT_IMAGE}" "Quarkus 3 Spring Compat"; then
                    ((images_built++))
                fi
                if build_image "apps/Dockerfile.spring3-jvm" "${REPO_DIR}/springboot3" "${SPRING3_JVM_IMAGE}" "Spring Boot 3 JVM"; then
                    ((images_built++))
                fi
                if build_image "apps/Dockerfile.spring4-jvm" "${REPO_DIR}/springboot4" "${SPRING4_JVM_IMAGE}" "Spring Boot 4 JVM"; then
                    ((images_built++))
                fi
                ;;
            quarkus3-jvm)
                if build_image "apps/Dockerfile.quarkus3-jvm" "${REPO_DIR}/quarkus3" "${QUARKUS3_JVM_IMAGE}" "Quarkus 3 JVM"; then
                    ((images_built++))
                fi
                ;;
            quarkus3-virtual)
                if build_image "apps/Dockerfile.quarkus3-virtual" "${REPO_DIR}/quarkus3-virtual" "${QUARKUS3_VIRTUAL_IMAGE}" "Quarkus 3 Virtual"; then
                    ((images_built++))
                fi
                ;;
            quarkus3-spring-compat)
                if build_image "apps/Dockerfile.quarkus3-spring-compat" "${REPO_DIR}/quarkus3-spring-compatibility" "${QUARKUS3_SPRING_COMPAT_IMAGE}" "Quarkus 3 Spring Compat"; then
                    ((images_built++))
                fi
                ;;
            spring3-jvm)
                if build_image "apps/Dockerfile.spring3-jvm" "${REPO_DIR}/springboot3" "${SPRING3_JVM_IMAGE}" "Spring Boot 3 JVM"; then
                    ((images_built++))
                fi
                ;;
            spring4-jvm)
                if build_image "apps/Dockerfile.spring4-jvm" "${REPO_DIR}/springboot4" "${SPRING4_JVM_IMAGE}" "Spring Boot 4 JVM"; then
                    ((images_built++))
                fi
                ;;
        esac
    done
    
    if [ $images_built -eq 0 ]; then
        print_error "No valid runtimes specified!"
        echo ""
        exit 1
    fi
    
    print_success "${images_built} image(s) built successfully!"
    
    # List images
    list_images
    
    # Ask if user wants to push images
    echo ""
    read -p "Do you want to push images to ${REGISTRY}/${REGISTRY_USER}? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "Step 3: Pushing Images to Registry"
        
        # Login to registry
        print_info "Logging in to ${REGISTRY}..."
        ${CONTAINER_CMD} login ${REGISTRY}
        
        if [ $? -ne 0 ]; then
            print_error "Failed to login to registry"
            exit 1
        fi
        
        # Push selected images
        for runtime in "${SELECTED_RUNTIMES[@]}"; do
            case "$runtime" in
                all)
                    push_image "${QUARKUS3_JVM_IMAGE}"
                    push_image "${QUARKUS3_VIRTUAL_IMAGE}"
                    push_image "${QUARKUS3_SPRING_COMPAT_IMAGE}"
                    push_image "${SPRING3_JVM_IMAGE}"
                    push_image "${SPRING3_VIRTUAL_IMAGE}"
                    push_image "${SPRING4_JVM_IMAGE}"
                    push_image "${SPRING4_VIRTUAL_IMAGE}"
                    ;;
                quarkus3-jvm)
                    push_image "${QUARKUS3_JVM_IMAGE}"
                    ;;
                quarkus3-virtual)
                    push_image "${QUARKUS3_VIRTUAL_IMAGE}"
                    ;;
                quarkus3-spring-compat)
                    push_image "${QUARKUS3_SPRING_COMPAT_IMAGE}"
                    ;;
                spring3-jvm)
                    push_image "${SPRING3_JVM_IMAGE}"
                    ;;
                spring3-virtual)
                    push_image "${SPRING3_VIRTUAL_IMAGE}"
                    ;;
                spring4-jvm)
                    push_image "${SPRING4_JVM_IMAGE}"
                    ;;
                spring4-virtual)
                    push_image "${SPRING4_VIRTUAL_IMAGE}"
                    ;;
            esac
        done
        
        print_success "Images pushed successfully!"
    fi
    
    echo ""
    echo "========================================================================"
    print_success "Build Process Completed!"
    echo "========================================================================"
    echo ""
    echo "Images created: ${images_built}"
    echo ""
    echo "Next steps:"
    echo "  1. Verify images: ${CONTAINER_CMD} images | grep ${REGISTRY_USER}"
    echo "  2. Test locally: ${CONTAINER_CMD} run -p 8080:8080 <image-name>"
    echo "  3. Check metrics: curl http://localhost:8080/q/metrics (Quarkus)"
    echo "                    curl http://localhost:8080/actuator/prometheus (Spring)"
    echo ""
}

# Run main function
main "$@"

# Made with Bob
