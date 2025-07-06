# =============================================================================
# Streaming Module Outputs
# =============================================================================

# Kinesis Stream Outputs
output "data_stream_name" {
  description = "Name of the main Kinesis data stream"
  value       = aws_kinesis_stream.data_stream.name
}

output "data_stream_arn" {
  description = "ARN of the main Kinesis data stream"
  value       = aws_kinesis_stream.data_stream.arn
}

output "error_stream_name" {
  description = "Name of the error Kinesis stream"
  value       = aws_kinesis_stream.error_stream.name
}

output "error_stream_arn" {
  description = "ARN of the error Kinesis stream"
  value       = aws_kinesis_stream.error_stream.arn
}

output "processed_stream_name" {
  description = "Name of the processed Kinesis stream"
  value       = var.enable_analytics_application ? aws_kinesis_stream.processed_stream[0].name : null
}

output "processed_stream_arn" {
  description = "ARN of the processed Kinesis stream"
  value       = var.enable_analytics_application ? aws_kinesis_stream.processed_stream[0].arn : null
}

# Firehose Delivery Stream Outputs
output "s3_delivery_stream_name" {
  description = "Name of the S3 delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.s3_delivery.name
}

output "s3_delivery_stream_arn" {
  description = "ARN of the S3 delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.s3_delivery.arn
}

output "opensearch_delivery_stream_name" {
  description = "Name of the OpenSearch delivery stream"
  value       = var.enable_opensearch_delivery ? aws_kinesis_firehose_delivery_stream.opensearch_delivery[0].name : null
}

output "opensearch_delivery_stream_arn" {
  description = "ARN of the OpenSearch delivery stream"
  value       = var.enable_opensearch_delivery ? aws_kinesis_firehose_delivery_stream.opensearch_delivery[0].arn : null
}

# Kinesis Analytics Outputs
output "analytics_application_name" {
  description = "Name of the Kinesis Analytics application"
  value       = var.enable_analytics_application ? aws_kinesis_analytics_application.real_time_analytics[0].name : null
}

output "analytics_application_arn" {
  description = "ARN of the Kinesis Analytics application"
  value       = var.enable_analytics_application ? aws_kinesis_analytics_application.real_time_analytics[0].arn : null
}

# MSK Outputs
output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = var.enable_msk ? aws_msk_cluster.kafka_cluster[0].arn : null
}

output "msk_cluster_name" {
  description = "Name of the MSK cluster"
  value       = var.enable_msk ? aws_msk_cluster.kafka_cluster[0].cluster_name : null
}

output "msk_bootstrap_brokers" {
  description = "Bootstrap brokers for the MSK cluster"
  value       = var.enable_msk ? aws_msk_cluster.kafka_cluster[0].bootstrap_brokers_sasl_iam : null
}

output "msk_security_group_id" {
  description = "Security group ID for MSK cluster"
  value       = var.enable_msk ? aws_security_group.msk_sg[0].id : null
}

# CloudWatch Log Groups
output "firehose_log_group_name" {
  description = "Name of the Firehose CloudWatch log group"
  value       = aws_cloudwatch_log_group.firehose_logs.name
}

output "firehose_log_group_arn" {
  description = "ARN of the Firehose CloudWatch log group"
  value       = aws_cloudwatch_log_group.firehose_logs.arn
}

output "msk_log_group_name" {
  description = "Name of the MSK CloudWatch log group"
  value       = var.enable_msk ? aws_cloudwatch_log_group.msk_logs[0].name : null
}

output "msk_log_group_arn" {
  description = "ARN of the MSK CloudWatch log group"
  value       = var.enable_msk ? aws_cloudwatch_log_group.msk_logs[0].arn : null
}

# CloudWatch Alarms
output "high_incoming_records_alarm_name" {
  description = "Name of the high incoming records alarm"
  value       = aws_cloudwatch_metric_alarm.high_incoming_records.alarm_name
}

output "iterator_age_alarm_name" {
  description = "Name of the iterator age alarm"
  value       = aws_cloudwatch_metric_alarm.iterator_age.alarm_name
} 