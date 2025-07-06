#!/bin/bash

# =============================================================================
# Setup Backend Script
# Bootstraps S3 buckets and DynamoDB tables for Terraform state management
# =============================================================================

set -euo pipefail

# Default values
DEFAULT_REGION="us-east-1"
DEFAULT_PROFILE=""

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
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap S3 buckets and DynamoDB tables for Terraform state management.

OPTIONS:
    -e, --environment   Environment (dev, staging, prod) [required]
    -r, --region        AWS region (default: ${DEFAULT_REGION})
    -p, --profile       AWS profile to use
    -f, --force         Force creation even if resources exist
    -h, --help          Display this help message

EXAMPLES:
    $0 -e dev
    $0 -e prod -r us-west-2 -p production
    $0 -e staging --force

EOF
}

# Function to validate AWS CLI installation
validate_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
}

# Function to validate AWS credentials
validate_aws_credentials() {
    local profile_arg=""
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        profile_arg="--profile ${AWS_PROFILE}"
    fi

    if ! aws sts get-caller-identity ${profile_arg} &> /dev/null; then
        print_error "AWS credentials not configured or invalid."
        print_error "Please run 'aws configure' or set AWS_PROFILE environment variable."
        exit 1
    fi

    local account_id
    account_id=$(aws sts get-caller-identity ${profile_arg} --query Account --output text)
    print_status "Using AWS Account: ${account_id}"
}

# Function to load configuration from YAML
load_config() {
    local environment=$1
    local config_file="${PROJECT_ROOT}/config/accounts.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file"
        exit 1
    fi

    # Extract configuration using yq (requires yq to be installed)
    if command -v yq &> /dev/null; then
        STATE_BUCKET=$(yq eval ".${environment}.terraform.state_bucket" "$config_file")
        LOCK_TABLE=$(yq eval ".${environment}.terraform.lock_table" "$config_file")
        ACCOUNT_ID=$(yq eval ".${environment}.aws.account_id" "$config_file")
    else
        print_warning "yq not found. Using default values."
        STATE_BUCKET="aws-data-platform-terraform-state-${environment}"
        LOCK_TABLE="aws-data-platform-terraform-lock-${environment}"
        ACCOUNT_ID=""
    fi

    print_status "Configuration loaded:"
    print_status "  State Bucket: ${STATE_BUCKET}"
    print_status "  Lock Table: ${LOCK_TABLE}"
    [[ -n "$ACCOUNT_ID" ]] && print_status "  Account ID: ${ACCOUNT_ID}"
}

# Function to create S3 bucket for state storage
create_state_bucket() {
    local bucket_name=$1
    local region=$2
    local profile_arg=""
    
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        profile_arg="--profile ${AWS_PROFILE}"
    fi

    print_status "Creating S3 bucket: ${bucket_name}"

    # Check if bucket already exists
    if aws s3api head-bucket --bucket "$bucket_name" ${profile_arg} 2>/dev/null; then
        if [[ "${FORCE:-false}" != "true" ]]; then
            print_warning "Bucket $bucket_name already exists. Use --force to continue."
            return 0
        else
            print_warning "Bucket $bucket_name already exists. Continuing due to --force flag."
        fi
    else
        # Create bucket
        if [[ "$region" == "us-east-1" ]]; then
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --region "$region" \
                ${profile_arg}
        else
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --region "$region" \
                --create-bucket-configuration LocationConstraint="$region" \
                ${profile_arg}
        fi
    fi

    # Enable versioning
    print_status "Enabling versioning on bucket: ${bucket_name}"
    aws s3api put-bucket-versioning \
        --bucket "$bucket_name" \
        --versioning-configuration Status=Enabled \
        ${profile_arg}

    # Enable server-side encryption
    print_status "Enabling server-side encryption on bucket: ${bucket_name}"
    aws s3api put-bucket-encryption \
        --bucket "$bucket_name" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    },
                    "BucketKeyEnabled": false
                }
            ]
        }' \
        ${profile_arg}

    # Block public access
    print_status "Blocking public access on bucket: ${bucket_name}"
    aws s3api put-public-access-block \
        --bucket "$bucket_name" \
        --public-access-block-configuration \
        'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' \
        ${profile_arg}

    # Add bucket policy for enhanced security
    print_status "Adding bucket policy for enhanced security"
    local bucket_policy=$(cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyUnSecureCommunications",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${bucket_name}",
                "arn:aws:s3:::${bucket_name}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
EOF
)

    echo "$bucket_policy" | aws s3api put-bucket-policy \
        --bucket "$bucket_name" \
        --policy file:///dev/stdin \
        ${profile_arg}

    print_success "S3 bucket ${bucket_name} created and configured successfully"
}

# Function to create DynamoDB table for state locking
create_lock_table() {
    local table_name=$1
    local region=$2
    local profile_arg=""
    
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        profile_arg="--profile ${AWS_PROFILE}"
    fi

    print_status "Creating DynamoDB table: ${table_name}"

    # Check if table already exists
    if aws dynamodb describe-table --table-name "$table_name" --region "$region" ${profile_arg} &>/dev/null; then
        if [[ "${FORCE:-false}" != "true" ]]; then
            print_warning "DynamoDB table $table_name already exists. Use --force to continue."
            return 0
        else
            print_warning "DynamoDB table $table_name already exists. Continuing due to --force flag."
            return 0
        fi
    fi

    # Create table
    aws dynamodb create-table \
        --table-name "$table_name" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$region" \
        ${profile_arg}

    # Wait for table to be active
    print_status "Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists \
        --table-name "$table_name" \
        --region "$region" \
        ${profile_arg}

    # Enable point-in-time recovery
    print_status "Enabling point-in-time recovery on table: ${table_name}"
    aws dynamodb update-continuous-backups \
        --table-name "$table_name" \
        --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
        --region "$region" \
        ${profile_arg}

    print_success "DynamoDB table ${table_name} created and configured successfully"
}

# Function to create backend configuration file
create_backend_config() {
    local environment=$1
    local region=$2
    local config_dir="${PROJECT_ROOT}/backend-configs"
    local config_file="${config_dir}/${environment}-${region}.hcl"

    print_status "Creating backend configuration file: ${config_file}"

    mkdir -p "$config_dir"

    cat > "$config_file" << EOF
# Backend configuration for ${environment} environment in ${region}
# Generated by setup-backend.sh on $(date)

bucket         = "${STATE_BUCKET}"
key            = "${environment}/${region}/terraform.tfstate"
region         = "${region}"
encrypt        = true
dynamodb_table = "${LOCK_TABLE}"

# Optional: Role to assume for backend operations
# role_arn = "arn:aws:iam::${ACCOUNT_ID:-ACCOUNT_ID}:role/TerraformExecutionRole"
EOF

    print_success "Backend configuration created: ${config_file}"
}

# Function to verify backend setup
verify_backend() {
    local bucket_name=$1
    local table_name=$2
    local region=$3
    local profile_arg=""
    
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        profile_arg="--profile ${AWS_PROFILE}"
    fi

    print_status "Verifying backend setup..."

    # Test S3 bucket access
    if aws s3api head-bucket --bucket "$bucket_name" ${profile_arg} 2>/dev/null; then
        print_success "✓ S3 bucket ${bucket_name} is accessible"
    else
        print_error "✗ S3 bucket ${bucket_name} is not accessible"
        return 1
    fi

    # Test DynamoDB table access
    if aws dynamodb describe-table --table-name "$table_name" --region "$region" ${profile_arg} &>/dev/null; then
        print_success "✓ DynamoDB table ${table_name} is accessible"
    else
        print_error "✗ DynamoDB table ${table_name} is not accessible"
        return 1
    fi

    print_success "Backend verification completed successfully"
}

# Main function
main() {
    local environment=""
    local region="$DEFAULT_REGION"
    local profile=""
    local force=false

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
            -p|--profile)
                profile="$2"
                export AWS_PROFILE="$profile"
                shift 2
                ;;
            -f|--force)
                force=true
                export FORCE="true"
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

    # Validate required arguments
    if [[ -z "$environment" ]]; then
        print_error "Environment is required. Use -e or --environment."
        usage
        exit 1
    fi

    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Environment must be one of: dev, staging, prod"
        exit 1
    fi

    print_status "Setting up Terraform backend for environment: ${environment}"
    print_status "Region: ${region}"
    [[ -n "$profile" ]] && print_status "AWS Profile: ${profile}"

    # Validate prerequisites
    validate_aws_cli
    validate_aws_credentials

    # Load configuration
    load_config "$environment"

    # Create resources
    create_state_bucket "$STATE_BUCKET" "$region"
    create_lock_table "$LOCK_TABLE" "$region"

    # Create backend configuration
    create_backend_config "$environment" "$region"

    # Verify setup
    verify_backend "$STATE_BUCKET" "$LOCK_TABLE" "$region"

    print_success "Terraform backend setup completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Review the backend configuration in backend-configs/${environment}-${region}.hcl"
    print_status "2. Run 'terraform init -backend-config=backend-configs/${environment}-${region}.hcl' in your Terraform directory"
    print_status "3. Or use Terragrunt with the generated configuration"
}

# Run main function
main "$@" 