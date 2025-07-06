# =============================================================================
# Monitoring Module Outputs
# =============================================================================

# SNS Topic Outputs
output "critical_alerts_topic_arn" {
  description = "ARN of the critical alerts SNS topic"
  value       = aws_sns_topic.critical_alerts.arn
}

output "critical_alerts_topic_name" {
  description = "Name of the critical alerts SNS topic"
  value       = aws_sns_topic.critical_alerts.name
}

output "warning_alerts_topic_arn" {
  description = "ARN of the warning alerts SNS topic"
  value       = aws_sns_topic.warning_alerts.arn
}

output "warning_alerts_topic_name" {
  description = "Name of the warning alerts SNS topic"
  value       = aws_sns_topic.warning_alerts.name
}

output "data_quality_alerts_topic_arn" {
  description = "ARN of the data quality alerts SNS topic"
  value       = aws_sns_topic.data_quality_alerts.arn
}

output "data_quality_alerts_topic_name" {
  description = "Name of the data quality alerts SNS topic"
  value       = aws_sns_topic.data_quality_alerts.name
}

# CloudWatch Log Group Outputs
output "application_log_group_name" {
  description = "Name of the application CloudWatch log group"
  value       = aws_cloudwatch_log_group.application_logs.name
}

output "application_log_group_arn" {
  description = "ARN of the application CloudWatch log group"
  value       = aws_cloudwatch_log_group.application_logs.arn
}

output "error_log_group_name" {
  description = "Name of the error CloudWatch log group"
  value       = aws_cloudwatch_log_group.error_logs.name
}

output "error_log_group_arn" {
  description = "ARN of the error CloudWatch log group"
  value       = aws_cloudwatch_log_group.error_logs.arn
}

output "audit_log_group_name" {
  description = "Name of the audit CloudWatch log group"
  value       = aws_cloudwatch_log_group.audit_logs.name
}

output "audit_log_group_arn" {
  description = "ARN of the audit CloudWatch log group"
  value       = aws_cloudwatch_log_group.audit_logs.arn
}

# CloudWatch Alarm Outputs
output "high_error_rate_alarm_name" {
  description = "Name of the high error rate alarm"
  value       = aws_cloudwatch_metric_alarm.high_error_rate.alarm_name
}

output "data_quality_issues_alarm_name" {
  description = "Name of the data quality issues alarm"
  value       = aws_cloudwatch_metric_alarm.data_quality_issues.alarm_name
}

output "lambda_error_alarm_names" {
  description = "Names of the Lambda error alarms"
  value       = aws_cloudwatch_metric_alarm.lambda_errors[*].alarm_name
}

output "lambda_duration_alarm_names" {
  description = "Names of the Lambda duration alarms"
  value       = aws_cloudwatch_metric_alarm.lambda_duration[*].alarm_name
}

output "step_functions_failures_alarm_name" {
  description = "Name of the Step Functions failures alarm"
  value       = var.step_functions_state_machine_name != null ? aws_cloudwatch_metric_alarm.step_functions_failures[0].alarm_name : null
}

output "s3_bucket_size_alarm_names" {
  description = "Names of the S3 bucket size alarms"
  value       = aws_cloudwatch_metric_alarm.s3_bucket_size[*].alarm_name
}

# CloudWatch Dashboard Output
output "main_dashboard_name" {
  description = "Name of the main monitoring dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "main_dashboard_url" {
  description = "URL of the main monitoring dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

# EventBridge Rule Outputs
output "lambda_failures_rule_name" {
  description = "Name of the Lambda failures EventBridge rule"
  value       = aws_cloudwatch_event_rule.lambda_failures.name
}

output "step_functions_failures_rule_name" {
  description = "Name of the Step Functions failures EventBridge rule"
  value       = var.step_functions_state_machine_name != null ? aws_cloudwatch_event_rule.step_functions_failures[0].name : null
} 