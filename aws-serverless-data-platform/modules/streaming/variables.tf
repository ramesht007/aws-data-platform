# =============================================================================
# Streaming Module Variables
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

# Kinesis Stream Configuration
variable "shard_count" {
  description = "Number of shards for the Kinesis stream"
  type        = number
  default     = 1
}

variable "retention_period" {
  description = "Retention period for Kinesis stream in hours"
  type        = number
  default     = 24
}

variable "stream_mode" {
  description = "Stream mode for Kinesis stream (PROVISIONED or ON_DEMAND)"
  type        = string
  default     = "PROVISIONED"
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

# Firehose Configuration
variable "firehose_role_arn" {
  description = "ARN of the Firehose service role"
  type        = string
}

variable "raw_data_bucket_arn" {
  description = "ARN of the S3 bucket for raw data"
  type        = string
}

variable "buffer_size" {
  description = "Buffer size for Firehose delivery in MB"
  type        = number
  default     = 5
}

variable "buffer_interval" {
  description = "Buffer interval for Firehose delivery in seconds"
  type        = number
  default     = 300
}

variable "enable_data_transformation" {
  description = "Enable data transformation in Firehose"
  type        = bool
  default     = false
}

variable "transformation_lambda_arn" {
  description = "ARN of the Lambda function for data transformation"
  type        = string
  default     = null
}

# OpenSearch Configuration
variable "enable_opensearch_delivery" {
  description = "Enable delivery to OpenSearch"
  type        = bool
  default     = false
}

variable "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  type        = string
  default     = null
}

# Kinesis Analytics Configuration
variable "enable_analytics_application" {
  description = "Enable Kinesis Analytics application"
  type        = bool
  default     = true
}

variable "analytics_role_arn" {
  description = "ARN of the Kinesis Analytics role"
  type        = string
}

# MSK Configuration
variable "enable_msk" {
  description = "Enable MSK (Managed Streaming for Apache Kafka)"
  type        = bool
  default     = false
}

variable "kafka_version" {
  description = "Version of Apache Kafka"
  type        = string
  default     = "2.8.1"
}

variable "number_of_broker_nodes" {
  description = "Number of broker nodes in the MSK cluster"
  type        = number
  default     = 3
}

variable "kafka_instance_type" {
  description = "Instance type for Kafka brokers"
  type        = string
  default     = "kafka.m5.large"
}

variable "kafka_subnet_ids" {
  description = "List of subnet IDs for MSK cluster"
  type        = list(string)
  default     = []
}

variable "kafka_volume_size" {
  description = "Size of EBS volume for each broker node in GB"
  type        = number
  default     = 100
}

variable "vpc_id" {
  description = "VPC ID for security groups"
  type        = string
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "logs_bucket_name" {
  description = "S3 bucket name for logs"
  type        = string
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# Monitoring Configuration
variable "high_incoming_records_threshold" {
  description = "Threshold for high incoming records alarm"
  type        = number
  default     = 10000
}

variable "iterator_age_threshold" {
  description = "Threshold for iterator age alarm in milliseconds"
  type        = number
  default     = 60000  # 1 minute
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = null
} 