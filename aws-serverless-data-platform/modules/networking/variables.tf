# =============================================================================
# Networking Module Variables
# Input variables for the networking module
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["test", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: test, dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Account ID must be a 12-digit number."
  }
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
}

variable "module_name" {
  description = "Name of the module"
  type        = string
  default     = "networking"
}

# Networking configuration from YAML
variable "networking" {
  description = "Networking configuration from YAML files"
  type = object({
    vpc = object({
      cidr                 = string
      enable_dns_hostnames = bool
      enable_dns_support   = bool
    })
    subnets = object({
      private  = list(string)
      public   = list(string)
      database = list(string)
    })
    availability_zones = number
    nat_gateway = object({
      enable             = bool
      single_nat_gateway = bool
    })
    flow_logs = object({
      enable         = bool
      retention_days = number
    })
  })
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional tags for networking resources"
  type        = map(string)
  default     = {}
}

# Optional DNS configuration
variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
} 