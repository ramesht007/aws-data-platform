#!/bin/bash

# =============================================================================
# Test All Script
# Runs all Terratest suites for the AWS Serverless Data Platform
# =============================================================================

set -euo pipefail

# Default values
DEFAULT_TIMEOUT="30m"
DEFAULT_PARALLELISM="4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TESTS_DIR="${PROJECT_ROOT}/tests"

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run Terratest suites for the AWS Serverless Data Platform.

OPTIONS:
    -t, --timeout       Test timeout [default: ${DEFAULT_TIMEOUT}]
    -p, --parallelism   Number of parallel tests [default: ${DEFAULT_PARALLELISM}]
    -m, --module        Run tests for specific module only
    -s, --short         Run short tests only (skip integration tests)
    -i, --integration   Run integration tests only
    -v, --verbose       Verbose output
    -c, --coverage      Generate test coverage report
    -r, --race          Enable race condition detection
    --clean             Clean test cache before running
    -h, --help          Display this help message

EXAMPLES:
    $0                           # Run all tests
    $0 -m networking            # Test only networking module
    $0 -s                       # Run short tests only
    $0 -i                       # Run integration tests only
    $0 -t 60m -p 2              # Custom timeout and parallelism

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."

    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed. Please install Go 1.21 or later."
        exit 1
    fi

    # Check Go version
    local go_version
    go_version=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
    local go_major
    go_major=$(echo "$go_version" | cut -d. -f1)
    local go_minor
    go_minor=$(echo "$go_version" | cut -d. -f2)
    
    if [[ $go_major -lt 1 ]] || [[ $go_major -eq 1 && $go_minor -lt 21 ]]; then
        print_error "Go version 1.21 or later is required. Found: $go_version"
        exit 1
    fi

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi

    # Check if terragrunt is installed
    if ! command -v terragrunt &> /dev/null; then
        print_error "Terragrunt is not installed. Please install it first."
        exit 1
    fi

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    # Validate AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure'."
        exit 1
    fi

    print_success "Prerequisites validated"
}

# Function to setup test environment
setup_test_environment() {
    print_status "Setting up test environment..."

    cd "$TESTS_DIR"

    # Initialize Go module if not already done
    if [[ ! -f "go.mod" ]]; then
        print_status "Initializing Go module..."
        go mod init github.com/your-org/aws-serverless-data-platform/tests
    fi

    # Download dependencies
    print_status "Downloading Go dependencies..."
    go mod download
    go mod verify

    print_success "Test environment setup completed"
}

# Function to clean test cache
clean_test_cache() {
    print_status "Cleaning test cache..."
    
    cd "$TESTS_DIR"
    go clean -testcache
    
    # Clean any .terragrunt-cache directories
    find "$PROJECT_ROOT" -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Clean any .terraform directories
    find "$PROJECT_ROOT" -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Test cache cleaned"
}

# Function to run module tests
run_module_tests() {
    local module=$1
    local timeout=$2
    local parallelism=$3
    local verbose=$4
    local coverage=$5
    local race=$6

    local module_test_dir="../modules/${module}/tests"
    
    if [[ ! -d "$module_test_dir" ]]; then
        print_warning "No tests found for module: $module"
        return 0
    fi

    print_status "Running tests for module: $module"

    cd "$TESTS_DIR"

    # Build test command
    local test_cmd="go test"
    test_cmd="$test_cmd -timeout $timeout"
    test_cmd="$test_cmd -parallel $parallelism"
    
    if [[ "$verbose" == "true" ]]; then
        test_cmd="$test_cmd -v"
    fi
    
    if [[ "$coverage" == "true" ]]; then
        test_cmd="$test_cmd -coverprofile=coverage_${module}.out"
        test_cmd="$test_cmd -covermode=atomic"
    fi
    
    if [[ "$race" == "true" ]]; then
        test_cmd="$test_cmd -race"
    fi
    
    test_cmd="$test_cmd $module_test_dir"

    print_status "Executing: $test_cmd"
    
    local start_time
    start_time=$(date +%s)
    
    if eval "$test_cmd"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "Module $module tests passed in ${duration}s"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_error "Module $module tests failed after ${duration}s"
        return 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    local timeout=$1
    local parallelism=$2
    local verbose=$3
    local coverage=$4
    local race=$5

    local integration_dir="./integration"
    
    if [[ ! -d "$integration_dir" ]]; then
        print_warning "No integration tests found"
        return 0
    fi

    print_status "Running integration tests..."

    cd "$TESTS_DIR"

    # Build test command
    local test_cmd="go test"
    test_cmd="$test_cmd -timeout $timeout"
    test_cmd="$test_cmd -parallel $parallelism"
    
    if [[ "$verbose" == "true" ]]; then
        test_cmd="$test_cmd -v"
    fi
    
    if [[ "$coverage" == "true" ]]; then
        test_cmd="$test_cmd -coverprofile=coverage_integration.out"
        test_cmd="$test_cmd -covermode=atomic"
    fi
    
    if [[ "$race" == "true" ]]; then
        test_cmd="$test_cmd -race"
    fi
    
    test_cmd="$test_cmd $integration_dir"

    print_status "Executing: $test_cmd"
    
    local start_time
    start_time=$(date +%s)
    
    if eval "$test_cmd"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "Integration tests passed in ${duration}s"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_error "Integration tests failed after ${duration}s"
        return 1
    fi
}

# Function to run all module tests
run_all_module_tests() {
    local timeout=$1
    local parallelism=$2
    local verbose=$3
    local coverage=$4
    local race=$5

    print_status "Running all module tests..."

    local modules=()
    local total_modules=0
    local passed_modules=0
    local failed_modules=0

    # Find all modules with tests
    for module_dir in "$PROJECT_ROOT"/modules/*/; do
        if [[ -d "$module_dir" ]]; then
            local module_name
            module_name=$(basename "$module_dir")
            local test_dir="$module_dir/tests"
            
            if [[ -d "$test_dir" ]] && find "$test_dir" -name "*_test.go" | grep -q .; then
                modules+=("$module_name")
            fi
        fi
    done

    total_modules=${#modules[@]}
    print_status "Found $total_modules modules with tests: ${modules[*]}"

    # Run tests for each module
    for module in "${modules[@]}"; do
        if run_module_tests "$module" "$timeout" "$parallelism" "$verbose" "$coverage" "$race"; then
            passed_modules=$((passed_modules + 1))
        else
            failed_modules=$((failed_modules + 1))
        fi
    done

    print_status ""
    print_status "========== MODULE TESTS SUMMARY =========="
    print_status "Total modules: $total_modules"
    print_status "Passed: $passed_modules"
    print_status "Failed: $failed_modules"
    print_status "=========================================="

    return $failed_modules
}

# Function to generate coverage report
generate_coverage_report() {
    print_status "Generating coverage report..."
    
    cd "$TESTS_DIR"
    
    # Combine coverage files
    local coverage_files=()
    for coverage_file in coverage_*.out; do
        if [[ -f "$coverage_file" ]]; then
            coverage_files+=("$coverage_file")
        fi
    done
    
    if [[ ${#coverage_files[@]} -eq 0 ]]; then
        print_warning "No coverage files found"
        return 0
    fi
    
    # Merge coverage files
    echo "mode: atomic" > coverage_combined.out
    for coverage_file in "${coverage_files[@]}"; do
        tail -n +2 "$coverage_file" >> coverage_combined.out
    done
    
    # Generate HTML report
    go tool cover -html=coverage_combined.out -o coverage_report.html
    
    # Generate text summary
    go tool cover -func=coverage_combined.out > coverage_summary.txt
    
    print_success "Coverage report generated:"
    print_status "  HTML report: ${TESTS_DIR}/coverage_report.html"
    print_status "  Text summary: ${TESTS_DIR}/coverage_summary.txt"
    
    # Print coverage summary
    local total_coverage
    total_coverage=$(tail -1 coverage_summary.txt | grep -oE '[0-9]+\.[0-9]+%')
    print_status "  Total coverage: $total_coverage"
}

# Main function
main() {
    local timeout="$DEFAULT_TIMEOUT"
    local parallelism="$DEFAULT_PARALLELISM"
    local module=""
    local short_tests=false
    local integration_only=false
    local verbose=false
    local coverage=false
    local race=false
    local clean=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -p|--parallelism)
                parallelism="$2"
                shift 2
                ;;
            -m|--module)
                module="$2"
                shift 2
                ;;
            -s|--short)
                short_tests=true
                shift
                ;;
            -i|--integration)
                integration_only=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -c|--coverage)
                coverage=true
                shift
                ;;
            -r|--race)
                race=true
                shift
                ;;
            --clean)
                clean=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate prerequisites
    validate_prerequisites

    # Setup test environment
    setup_test_environment

    # Clean cache if requested
    if [[ "$clean" == "true" ]]; then
        clean_test_cache
    fi

    local overall_start_time
    overall_start_time=$(date +%s)
    local exit_code=0

    # Run tests based on options
    if [[ "$integration_only" == "true" ]]; then
        # Run only integration tests
        if ! run_integration_tests "$timeout" "$parallelism" "$verbose" "$coverage" "$race"; then
            exit_code=1
        fi
    elif [[ -n "$module" ]]; then
        # Run tests for specific module
        if ! run_module_tests "$module" "$timeout" "$parallelism" "$verbose" "$coverage" "$race"; then
            exit_code=1
        fi
    elif [[ "$short_tests" == "true" ]]; then
        # Run only module tests (no integration)
        if ! run_all_module_tests "$timeout" "$parallelism" "$verbose" "$coverage" "$race"; then
            exit_code=1
        fi
    else
        # Run all tests
        if ! run_all_module_tests "$timeout" "$parallelism" "$verbose" "$coverage" "$race"; then
            exit_code=1
        fi
        
        if ! run_integration_tests "$timeout" "$parallelism" "$verbose" "$coverage" "$race"; then
            exit_code=1
        fi
    fi

    # Generate coverage report if requested
    if [[ "$coverage" == "true" ]]; then
        generate_coverage_report
    fi

    local overall_end_time
    overall_end_time=$(date +%s)
    local total_duration=$((overall_end_time - overall_start_time))

    print_status ""
    print_status "========== OVERALL TEST SUMMARY =========="
    print_status "Total execution time: ${total_duration}s"
    if [[ $exit_code -eq 0 ]]; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed!"
    fi
    print_status "=========================================="

    exit $exit_code
}

# Run main function
main "$@" 