# =============================================================================
# Monitoring Module Variables
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

# KMS Configuration
variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

# SNS Configuration
variable "critical_alert_emails" {
  description = "List of email addresses for critical alerts"
  type        = list(string)
  default     = []
}

variable "warning_alert_emails" {
  description = "List of email addresses for warning alerts"
  type        = list(string)
  default     = []
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Number of days to retain application CloudWatch logs"
  type        = number
  default     = 30
}

variable "error_log_retention_days" {
  description = "Number of days to retain error CloudWatch logs"
  type        = number
  default     = 90
}

variable "audit_log_retention_days" {
  description = "Number of days to retain audit CloudWatch logs"
  type        = number
  default     = 365
}

# Alarm Thresholds
variable "error_threshold" {
  description = "Threshold for error count alarm"
  type        = number
  default     = 10
}

variable "data_quality_threshold" {
  description = "Threshold for data quality issues alarm"
  type        = number
  default     = 5
}

variable "lambda_duration_threshold" {
  description = "Threshold for Lambda function duration in milliseconds"
  type        = number
  default     = 60000  # 1 minute
}

variable "s3_bucket_size_threshold" {
  description = "Threshold for S3 bucket size alarm in bytes"
  type        = number
  default     = 107374182400  # 100 GB
}

# Resource Monitoring Configuration
variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

variable "step_functions_state_machine_name" {
  description = "Name of the Step Functions state machine to monitor"
  type        = string
  default     = null
}

variable "step_functions_state_machine_arn" {
  description = "ARN of the Step Functions state machine to monitor"
  type        = string
  default     = null
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names to monitor"
  type        = list(string)
  default     = []
} 