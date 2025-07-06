# =============================================================================
# Orchestration Module Variables
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

# Lambda Configuration
variable "enable_lambda_functions" {
  description = "Enable Lambda functions"
  type        = bool
  default     = true
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "lambda_subnet_ids" {
  description = "List of subnet IDs for Lambda functions"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

# S3 Bucket Configuration
variable "raw_data_bucket" {
  description = "S3 bucket name for raw data"
  type        = string
}

variable "processed_data_bucket" {
  description = "S3 bucket name for processed data"
  type        = string
}

variable "curated_data_bucket" {
  description = "S3 bucket name for curated data"
  type        = string
}

variable "error_bucket" {
  description = "S3 bucket name for error data"
  type        = string
}

# Kinesis Configuration
variable "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  type        = string
  default     = null
}

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream"
  type        = string
  default     = null
}

# Glue Configuration
variable "glue_database_name" {
  description = "Name of the Glue database"
  type        = string
}

# SNS Configuration
variable "notification_sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = null
}

# Step Functions Configuration
variable "enable_step_functions" {
  description = "Enable Step Functions state machine"
  type        = bool
  default     = true
}

variable "step_functions_role_arn" {
  description = "ARN of the Step Functions execution role"
  type        = string
}

variable "step_functions_log_level" {
  description = "Log level for Step Functions (OFF, ALL, ERROR, FATAL)"
  type        = string
  default     = "ERROR"
}

# EventBridge Configuration
variable "enable_scheduled_execution" {
  description = "Enable scheduled execution of the pipeline"
  type        = bool
  default     = true
}

variable "pipeline_schedule" {
  description = "Schedule expression for pipeline execution"
  type        = string
  default     = "cron(0 6 * * ? *)"  # Daily at 6 AM UTC
}

variable "eventbridge_role_arn" {
  description = "ARN of the EventBridge execution role"
  type        = string
}

# MWAA Configuration
variable "enable_mwaa" {
  description = "Enable MWAA (Managed Apache Airflow)"
  type        = bool
  default     = false
}

variable "airflow_version" {
  description = "Version of Apache Airflow"
  type        = string
  default     = "2.5.1"
}

variable "airflow_environment_class" {
  description = "Environment class for MWAA"
  type        = string
  default     = "mw1.small"
}

variable "airflow_max_workers" {
  description = "Maximum number of workers for MWAA"
  type        = number
  default     = 10
}

variable "airflow_min_workers" {
  description = "Minimum number of workers for MWAA"
  type        = number
  default     = 1
}

variable "airflow_schedulers" {
  description = "Number of schedulers for MWAA"
  type        = number
  default     = 2
}

variable "airflow_s3_bucket_arn" {
  description = "ARN of the S3 bucket for MWAA"
  type        = string
  default     = null
}

variable "mwaa_execution_role_arn" {
  description = "ARN of the MWAA execution role"
  type        = string
  default     = null
}

variable "mwaa_subnet_ids" {
  description = "List of subnet IDs for MWAA"
  type        = list(string)
  default     = []
}

variable "airflow_configuration_options" {
  description = "Configuration options for Airflow"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for security groups"
  type        = string
}

# S3 Triggers Configuration
variable "enable_s3_triggers" {
  description = "Enable S3 event triggers for Lambda functions"
  type        = bool
  default     = true
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
} 