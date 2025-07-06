# =============================================================================
# Storage Module Variables
# Input variables for the storage module
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["test", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
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

variable "module_name" {
  description = "Name of the module"
  type        = string
  default     = "storage"
}

# S3 bucket names
variable "data_lake_bucket_name" {
  description = "Base name for the data lake bucket"
  type        = string
  default     = "aws-data-platform-datalake"
}

variable "raw_bucket_name" {
  description = "Base name for the raw data bucket"
  type        = string
  default     = "aws-data-platform-raw"
}

variable "processed_bucket_name" {
  description = "Base name for the processed data bucket"
  type        = string
  default     = "aws-data-platform-processed"
}

variable "curated_bucket_name" {
  description = "Base name for the curated data bucket"
  type        = string
  default     = "aws-data-platform-curated"
}

# Storage configuration from YAML
variable "storage" {
  description = "Storage configuration from YAML files"
  type = object({
    s3 = object({
      versioning          = bool
      encryption          = string
      public_access_block = bool
      force_destroy       = bool
    })
    lifecycle = object({
      transition_ia_days           = number
      transition_glacier_days      = number
      transition_deep_archive_days = number
      expiration_days              = number
    })
  })
}

# Security configuration from YAML
variable "security" {
  description = "Security configuration from YAML files"
  type = object({
    kms = object({
      deletion_window     = number
      enable_key_rotation = bool
    })
  })
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional tags for storage resources"
  type        = map(string)
  default     = {}
} 

# Glue variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

# variable "glue_role_name" {
#   description = "Name of the Glue service role"
#   type        = string
# }

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}