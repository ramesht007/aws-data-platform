# =============================================================================
# Storage Module Outputs
# Outputs for use by other modules
# =============================================================================

# S3 Bucket Outputs
output "raw_bucket_id" {
  description = "ID of the raw data bucket"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  description = "ARN of the raw data bucket"
  value       = aws_s3_bucket.raw.arn
}

output "raw_bucket_domain_name" {
  description = "Domain name of the raw data bucket"
  value       = aws_s3_bucket.raw.bucket_domain_name
}

output "processed_bucket_id" {
  description = "ID of the processed data bucket"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "ARN of the processed data bucket"
  value       = aws_s3_bucket.processed.arn
}

output "processed_bucket_domain_name" {
  description = "Domain name of the processed data bucket"
  value       = aws_s3_bucket.processed.bucket_domain_name
}

output "curated_bucket_id" {
  description = "ID of the curated data bucket"
  value       = aws_s3_bucket.curated.id
}

output "curated_bucket_arn" {
  description = "ARN of the curated data bucket"
  value       = aws_s3_bucket.curated.arn
}

output "curated_bucket_domain_name" {
  description = "Domain name of the curated data bucket"
  value       = aws_s3_bucket.curated.bucket_domain_name
}

# KMS Key Outputs
output "s3_kms_key_id" {
  description = "ID of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3.key_id
}

output "s3_kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "s3_kms_alias_arn" {
  description = "ARN of the KMS key alias"
  value       = aws_kms_alias.s3.arn
}

# Bucket collections for easy reference
output "all_bucket_ids" {
  description = "List of all bucket IDs"
  value = [
    aws_s3_bucket.raw.id,
    aws_s3_bucket.processed.id,
    aws_s3_bucket.curated.id
  ]
}

output "all_bucket_arns" {
  description = "List of all bucket ARNs"
  value = [
    aws_s3_bucket.raw.arn,
    aws_s3_bucket.processed.arn,
    aws_s3_bucket.curated.arn
  ]
}

# Storage summary
output "storage_summary" {
  description = "Summary of storage configuration"
  value = {
    raw_bucket       = aws_s3_bucket.raw.id
    processed_bucket = aws_s3_bucket.processed.id
    curated_bucket   = aws_s3_bucket.curated.id
    kms_key_id       = aws_kms_key.s3.key_id
    encryption_type  = var.storage.s3.encryption
    versioning_enabled = var.storage.s3.versioning
  }
}

output "raw_bucket_lifecycle_configuration" {
  description = "Lifecycle configuration of the raw data bucket"
  value       = aws_s3_bucket_lifecycle_configuration.raw
}

output "processed_bucket_lifecycle_configuration" {
  description = "Lifecycle configuration of the processed data bucket"
  value       = aws_s3_bucket_lifecycle_configuration.processed
}

output "curated_bucket_lifecycle_configuration" {
  description = "Lifecycle configuration of the curated data bucket"
  value       = aws_s3_bucket_lifecycle_configuration.curated
}

output "raw_bucket_encryption" {
  description = "Encryption configuration of the raw data bucket"
  value       = aws_s3_bucket_server_side_encryption_configuration.raw
}

output "processed_bucket_encryption" {
  description = "Encryption configuration of the processed data bucket"
  value       = aws_s3_bucket_server_side_encryption_configuration.processed
}

output "curated_bucket_encryption" {
  description = "Encryption configuration of the curated data bucket"
  value       = aws_s3_bucket_server_side_encryption_configuration.curated
}

# Database Outputs
output "main_database_name" {
  description = "Name of the main Glue catalog database"
  value       = aws_glue_catalog_database.main.name
}

output "raw_database_name" {
  description = "Name of the raw data Glue catalog database"
  value       = aws_glue_catalog_database.raw.name
}

output "processed_database_name" {
  description = "Name of the processed data Glue catalog database"
  value       = aws_glue_catalog_database.processed.name
}

output "curated_database_name" {
  description = "Name of the curated data Glue catalog database"
  value       = aws_glue_catalog_database.curated.name
}

# CloudWatch Log Group
output "glue_log_group_name" {
  description = "Name of the Glue CloudWatch log group"
  value       = aws_cloudwatch_log_group.glue_logs.name
}

output "glue_log_group_arn" {
  description = "ARN of the Glue CloudWatch log group"
  value       = aws_cloudwatch_log_group.glue_logs.arn
} 