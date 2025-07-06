#!/bin/bash

# =============================================================================
# Deployment Script
# Runs terragrunt apply across all modules in dependency order
# =============================================================================

set -euo pipefail

# Default values
DEFAULT_ENVIRONMENT="dev"
DEFAULT_REGION="us-east-1"
DEFAULT_ACTION="apply"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy infrastructure using Terragrunt.

OPTIONS:
    -e, --environment   Environment (dev, staging, prod) [default: ${DEFAULT_ENVIRONMENT}]
    -r, --region        AWS region [default: ${DEFAULT_REGION}]
    -a, --action        Action (plan, apply, destroy) [default: ${DEFAULT_ACTION}]
    -m, --module        Deploy specific module only
    -f, --force         Force deployment (auto-approve)
    -p, --parallelism   Number of parallel operations [default: 10]
    -h, --help          Display this help message

EXAMPLES:
    $0 -e dev -a plan
    $0 -e prod -a apply -f
    $0 -e staging -m networking
    $0 -e dev -a destroy

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
    # Check if terragrunt is installed
    if ! command -v terragrunt &> /dev/null; then
        print_error "Terragrunt is not installed. Please install it first."
        exit 1
    fi

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
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
}

# Function to validate environment
validate_environment() {
    local environment=$1
    local region=$2
    local env_dir="${PROJECT_ROOT}/environments/${environment}/${region}"

    if [[ ! -d "$env_dir" ]]; then
        print_error "Environment directory not found: $env_dir"
        exit 1
    fi

    print_status "Environment validated: ${environment}/${region}"
}

# Function to get deployment order
get_deployment_order() {
    local action=$1
    
    if [[ "$action" == "destroy" ]]; then
        # Reverse order for destruction
        echo "08-monitoring 07-analytics 06-orchestration 05-streaming 04-data-catalog 03-storage 02-security 01-networking"
    else
        # Normal order for apply/plan
        echo "01-networking 02-security 03-storage 04-data-catalog 05-streaming 06-orchestration 07-analytics 08-monitoring"
    fi
}

# Function to run terragrunt command
run_terragrunt() {
    local module_path=$1
    local action=$2
    local force=$3
    local parallelism=$4

    if [[ ! -d "$module_path" ]]; then
        print_warning "Module directory not found: $module_path. Skipping."
        return 0
    fi

    local module_name=$(basename "$module_path")
    print_status "Running $action for module: $module_name"

    cd "$module_path"

    # Prepare terragrunt command
    local cmd="terragrunt $action"
    
    # Add flags based on action
    case $action in
        "plan")
            cmd="$cmd -detailed-exitcode"
            ;;
        "apply")
            if [[ "$force" == "true" ]]; then
                cmd="$cmd -auto-approve"
            fi
            cmd="$cmd -parallelism=$parallelism"
            ;;
        "destroy")
            if [[ "$force" == "true" ]]; then
                cmd="$cmd -auto-approve"
            fi
            cmd="$cmd -parallelism=$parallelism"
            ;;
    esac

    # Execute command
    print_status "Executing: $cmd"
    
    local start_time=$(date +%s)
    if eval "$cmd"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "$action completed for $module_name in ${duration}s"
        return 0
    else
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ "$action" == "plan" && $exit_code -eq 2 ]]; then
            print_warning "$action completed for $module_name with changes detected in ${duration}s"
            return 2
        else
            print_error "$action failed for $module_name after ${duration}s (exit code: $exit_code)"
            return $exit_code
        fi
    fi
}

# Function to deploy all modules
deploy_all_modules() {
    local environment=$1
    local region=$2
    local action=$3
    local force=$4
    local parallelism=$5
    
    local env_dir="${PROJECT_ROOT}/environments/${environment}/${region}"
    local deployment_order
    deployment_order=$(get_deployment_order "$action")
    
    local total_modules=0
    local successful_modules=0
    local failed_modules=0
    local changed_modules=0

    print_status "Starting $action for all modules in $environment/$region"
    print_status "Deployment order: $deployment_order"

    for module in $deployment_order; do
        local module_path="$env_dir/$module"
        total_modules=$((total_modules + 1))
        
        if run_terragrunt "$module_path" "$action" "$force" "$parallelism"; then
            local exit_code=$?
            if [[ $exit_code -eq 2 ]]; then
                changed_modules=$((changed_modules + 1))
            fi
            successful_modules=$((successful_modules + 1))
        else
            failed_modules=$((failed_modules + 1))
            print_error "Module $module failed. Stopping deployment."
            break
        fi
    done

    # Print summary
    print_status ""
    print_status "========== DEPLOYMENT SUMMARY =========="
    print_status "Environment: $environment/$region"
    print_status "Action: $action"
    print_status "Total modules: $total_modules"
    print_status "Successful: $successful_modules"
    print_status "Failed: $failed_modules"
    [[ "$action" == "plan" ]] && print_status "With changes: $changed_modules"
    print_status "========================================"

    if [[ $failed_modules -gt 0 ]]; then
        print_error "Deployment completed with failures"
        return 1
    else
        print_success "Deployment completed successfully"
        return 0
    fi
}

# Function to deploy single module
deploy_single_module() {
    local environment=$1
    local region=$2
    local module=$3
    local action=$4
    local force=$5
    local parallelism=$6
    
    local env_dir="${PROJECT_ROOT}/environments/${environment}/${region}"
    local module_path="$env_dir/$module"

    print_status "Starting $action for module $module in $environment/$region"

    if run_terragrunt "$module_path" "$action" "$force" "$parallelism"; then
        print_success "Module $module completed successfully"
        return 0
    else
        print_error "Module $module failed"
        return 1
    fi
}

# Function to initialize workspace
initialize_workspace() {
    local environment=$1
    local region=$2
    local module=${3:-""}
    
    local env_dir="${PROJECT_ROOT}/environments/${environment}/${region}"
    
    if [[ -n "$module" ]]; then
        # Initialize single module
        local module_path="$env_dir/$module"
        if [[ -d "$module_path" ]]; then
            print_status "Initializing module: $module"
            cd "$module_path"
            terragrunt init
        fi
    else
        # Initialize all modules
        print_status "Initializing all modules in $environment/$region"
        cd "$env_dir"
        terragrunt run-all init
    fi
}

# Main function
main() {
    local environment="$DEFAULT_ENVIRONMENT"
    local region="$DEFAULT_REGION"
    local action="$DEFAULT_ACTION"
    local module=""
    local force=false
    local parallelism=10
    local init_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -r|--region)
                region="$2"
                shift 2
                ;;
            -a|--action)
                action="$2"
                shift 2
                ;;
            -m|--module)
                module="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -p|--parallelism)
                parallelism="$2"
                shift 2
                ;;
            --init-only)
                init_only=true
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

    # Validate arguments
    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Environment must be one of: dev, staging, prod"
        exit 1
    fi

    if [[ ! "$action" =~ ^(plan|apply|destroy)$ ]]; then
        print_error "Action must be one of: plan, apply, destroy"
        exit 1
    fi

    # Validate prerequisites
    validate_prerequisites
    validate_environment "$environment" "$region"

    # Initialize workspace if requested
    if [[ "$init_only" == "true" ]]; then
        initialize_workspace "$environment" "$region" "$module"
        exit 0
    fi

    # Confirm destructive actions
    if [[ "$action" == "destroy" && "$force" != "true" ]]; then
        print_warning "This will DESTROY infrastructure in $environment/$region"
        read -p "Are you sure? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
            print_status "Operation cancelled"
            exit 0
        fi
    fi

    # Run deployment
    local start_time=$(date +%s)
    
    if [[ -n "$module" ]]; then
        deploy_single_module "$environment" "$region" "$module" "$action" "$force" "$parallelism"
    else
        deploy_all_modules "$environment" "$region" "$action" "$force" "$parallelism"
    fi
    
    local exit_code=$?
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    print_status "Total execution time: ${total_duration}s"
    exit $exit_code
}

# Run main function
main "$@" 