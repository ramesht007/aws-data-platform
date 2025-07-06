# =============================================================================
# Data Catalog Module Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

# Glue Configuration
variable "glue_role_arn" {
  description = "ARN of the Glue service role"
  type        = string
}

variable "glue_role_name" {
  description = "Name of the Glue service role"
  type        = string
}

# S3 Bucket Configuration
variable "raw_data_bucket" {
  description = "S3 bucket for raw data"
  type        = string
}

variable "processed_data_bucket" {
  description = "S3 bucket for processed data"
  type        = string
}

variable "curated_data_bucket" {
  description = "S3 bucket for curated data"
  type        = string
}

variable "scripts_bucket" {
  description = "S3 bucket for Glue scripts"
  type        = string
}

variable "temp_bucket" {
  description = "S3 bucket for temporary files"
  type        = string
}

variable "logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# Sample Data Configuration
variable "create_sample_tables" {
  description = "Create sample tables for demonstration"
  type        = bool
  default     = false
} 