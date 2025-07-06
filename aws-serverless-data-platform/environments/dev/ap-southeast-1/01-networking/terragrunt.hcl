# =============================================================================
# Networking Module - Development Environment (ap-southeast-1)
# VPC, Subnets, NAT Gateways, and networking components
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules//networking"
}

locals {
  environment = "dev"
  region      = "ap-southeast-1"
}

inputs = {
  # Module-specific inputs will be merged with global inputs from root.hcl
  # The root.hcl already provides all the configuration from YAML files
  
  # Additional module-specific overrides can be added here if needed
  module_name = "networking"
  
  # Networking-specific configuration
  vpc_name = "vpc-${local.environment}-${local.region}"
  
  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # Additional tags for networking resources
  additional_tags = {
    Module = "networking"
    Layer  = "infrastructure"
  }
} 