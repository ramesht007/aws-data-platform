# =============================================================================
# Analytics Module Variables
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

# Athena Configuration
variable "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "bytes_scanned_cutoff_per_query" {
  description = "Athena bytes scanned cutoff per query in bytes"
  type        = number
  default     = 10737418240  # 10 GB
}

variable "create_sample_queries" {
  description = "Create sample Athena named queries"
  type        = bool
  default     = true
}

variable "glue_database_name" {
  description = "Name of the Glue database"
  type        = string
}

# OpenSearch Configuration
variable "enable_opensearch" {
  description = "Enable OpenSearch domain"
  type        = bool
  default     = false
}

variable "opensearch_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.3"
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch nodes"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "opensearch_dedicated_master_enabled" {
  description = "Enable dedicated master nodes for OpenSearch"
  type        = bool
  default     = false
}

variable "opensearch_dedicated_master_type" {
  description = "Instance type for OpenSearch dedicated master nodes"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_dedicated_master_count" {
  description = "Number of OpenSearch dedicated master nodes"
  type        = number
  default     = 3
}

variable "opensearch_zone_awareness_enabled" {
  description = "Enable zone awareness for OpenSearch"
  type        = bool
  default     = false
}

variable "opensearch_availability_zone_count" {
  description = "Number of availability zones for OpenSearch"
  type        = number
  default     = 2
}

variable "opensearch_ebs_volume_size" {
  description = "Size of EBS volumes for OpenSearch in GB"
  type        = number
  default     = 20
}

variable "opensearch_subnet_ids" {
  description = "List of subnet IDs for OpenSearch"
  type        = list(string)
  default     = []
}

variable "opensearch_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access OpenSearch"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "opensearch_master_user_name" {
  description = "Master user name for OpenSearch"
  type        = string
  default     = "admin"
}

variable "opensearch_master_user_password" {
  description = "Master user password for OpenSearch"
  type        = string
  sensitive   = true
  default     = null
}

variable "vpc_id" {
  description = "VPC ID for OpenSearch security group"
  type        = string
}

# QuickSight Configuration
variable "enable_quicksight" {
  description = "Enable QuickSight resources"
  type        = bool
  default     = false
}

variable "create_sample_datasets" {
  description = "Create sample QuickSight datasets"
  type        = bool
  default     = false
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "create_cloudwatch_dashboard" {
  description = "Create CloudWatch dashboard for analytics"
  type        = bool
  default     = true
} 