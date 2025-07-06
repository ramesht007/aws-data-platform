# =============================================================================
# Data Catalog Module Outputs
# =============================================================================

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