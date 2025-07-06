# =============================================================================
# Storage Module - Development Environment (us-east-1)
# S3 buckets, data lake storage, and lifecycle management
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules//storage"
}

dependency "networking" {
  config_path = "../01-networking"
  
  mock_outputs = {
    vpc_id             = "vpc-12345678"
    private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
  }
}

locals {
  environment = "dev"
  region      = "us-east-1"
}

inputs = {
  # Dependencies from other modules
  vpc_id             = dependency.networking.outputs.vpc_id
  private_subnet_ids = dependency.networking.outputs.private_subnet_ids
  
  # Module-specific inputs
  module_name = "storage"
  
  # S3 bucket configuration
  data_lake_bucket_name = "aws-data-platform-datalake-${local.environment}-${local.region}"
  raw_bucket_name       = "aws-data-platform-raw-${local.environment}-${local.region}"
  processed_bucket_name = "aws-data-platform-processed-${local.environment}-${local.region}"
  curated_bucket_name   = "aws-data-platform-curated-${local.environment}-${local.region}"
  
  # Additional tags for storage resources
  additional_tags = {
    Module = "storage"
    Layer  = "data"
  }
} 