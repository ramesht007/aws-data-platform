# =============================================================================
# Analytics Module Outputs
# =============================================================================

# Athena Outputs
output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.main.name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = aws_athena_workgroup.main.arn
}

output "sample_analytics_query_id" {
  description = "ID of the sample analytics named query"
  value       = var.create_sample_queries ? aws_athena_named_query.sample_analytics[0].query_id : null
}

output "data_quality_check_query_id" {
  description = "ID of the data quality check named query"
  value       = var.create_sample_queries ? aws_athena_named_query.data_quality_check[0].query_id : null
}

# OpenSearch Outputs
output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = var.enable_opensearch ? aws_opensearch_domain.main[0].arn : null
}

output "opensearch_domain_id" {
  description = "ID of the OpenSearch domain"
  value       = var.enable_opensearch ? aws_opensearch_domain.main[0].domain_id : null
}

output "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  value       = var.enable_opensearch ? aws_opensearch_domain.main[0].domain_name : null
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = var.enable_opensearch ? aws_opensearch_domain.main[0].endpoint : null
}

output "opensearch_kibana_endpoint" {
  description = "OpenSearch Kibana endpoint"
  value       = var.enable_opensearch ? aws_opensearch_domain.main[0].kibana_endpoint : null
}

output "opensearch_security_group_id" {
  description = "Security group ID for OpenSearch"
  value       = var.enable_opensearch ? aws_security_group.opensearch_sg[0].id : null
}

# QuickSight Outputs
output "quicksight_data_source_arn" {
  description = "ARN of the QuickSight data source"
  value       = var.enable_quicksight ? aws_quicksight_data_source.athena[0].arn : null
}

output "quicksight_data_source_id" {
  description = "ID of the QuickSight data source"
  value       = var.enable_quicksight ? aws_quicksight_data_source.athena[0].data_source_id : null
}

output "quicksight_dataset_arn" {
  description = "ARN of the QuickSight dataset"
  value       = var.enable_quicksight && var.create_sample_datasets ? aws_quicksight_data_set.user_analytics[0].arn : null
}

output "quicksight_dataset_id" {
  description = "ID of the QuickSight dataset"
  value       = var.enable_quicksight && var.create_sample_datasets ? aws_quicksight_data_set.user_analytics[0].data_set_id : null
}

# CloudWatch Outputs
output "athena_log_group_name" {
  description = "Name of the Athena CloudWatch log group"
  value       = aws_cloudwatch_log_group.athena_logs.name
}

output "athena_log_group_arn" {
  description = "ARN of the Athena CloudWatch log group"
  value       = aws_cloudwatch_log_group.athena_logs.arn
}

output "opensearch_log_group_name" {
  description = "Name of the OpenSearch CloudWatch log group"
  value       = var.enable_opensearch ? aws_cloudwatch_log_group.opensearch_logs[0].name : null
}

output "opensearch_log_group_arn" {
  description = "ARN of the OpenSearch CloudWatch log group"
  value       = var.enable_opensearch ? aws_cloudwatch_log_group.opensearch_logs[0].arn : null
}

output "analytics_dashboard_name" {
  description = "Name of the analytics CloudWatch dashboard"
  value       = var.create_cloudwatch_dashboard ? aws_cloudwatch_dashboard.analytics_dashboard[0].dashboard_name : null
} 