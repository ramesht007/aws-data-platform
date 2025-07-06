# =============================================================================
# Orchestration Module Outputs
# =============================================================================

# Lambda Function Outputs
output "data_ingestion_lambda_arn" {
  description = "ARN of the data ingestion Lambda function"
  value       = var.enable_lambda_functions ? aws_lambda_function.data_ingestion[0].arn : null
}

output "data_ingestion_lambda_name" {
  description = "Name of the data ingestion Lambda function"
  value       = var.enable_lambda_functions ? aws_lambda_function.data_ingestion[0].function_name : null
}

output "data_transformation_lambda_arn" {
  description = "ARN of the data transformation Lambda function"
  value       = var.enable_lambda_functions ? aws_lambda_function.data_transformation[0].arn : null
}

output "data_transformation_lambda_name" {
  description = "Name of the data transformation Lambda function"
  value       = var.enable_lambda_functions ? aws_lambda_function.data_transformation[0].function_name : null
}

output "data_quality_lambda_arn" {
  description = "ARN of the data quality Lambda function"
  value       = var.enable_lambda_functions ? aws_lambda_function.data_quality[0].arn : null
}

output "data_quality_lambda_name" {
  description = "Name of the data quality Lambda function"
  value       = var.enable_lambda_functions ? aws_lambda_function.data_quality[0].function_name : null
}

# SQS Outputs
output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = var.enable_lambda_functions ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = var.enable_lambda_functions ? aws_sqs_queue.dlq[0].id : null
}

# Step Functions Outputs
output "step_functions_state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = var.enable_step_functions ? aws_sfn_state_machine.data_pipeline[0].arn : null
}

output "step_functions_state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = var.enable_step_functions ? aws_sfn_state_machine.data_pipeline[0].name : null
}

# EventBridge Outputs
output "daily_pipeline_rule_arn" {
  description = "ARN of the daily pipeline EventBridge rule"
  value       = var.enable_scheduled_execution ? aws_cloudwatch_event_rule.daily_pipeline[0].arn : null
}

output "daily_pipeline_rule_name" {
  description = "Name of the daily pipeline EventBridge rule"
  value       = var.enable_scheduled_execution ? aws_cloudwatch_event_rule.daily_pipeline[0].name : null
}

# MWAA Outputs
output "mwaa_environment_arn" {
  description = "ARN of the MWAA environment"
  value       = var.enable_mwaa ? aws_mwaa_environment.airflow[0].arn : null
}

output "mwaa_environment_name" {
  description = "Name of the MWAA environment"
  value       = var.enable_mwaa ? aws_mwaa_environment.airflow[0].name : null
}

output "mwaa_webserver_url" {
  description = "URL of the MWAA webserver"
  value       = var.enable_mwaa ? aws_mwaa_environment.airflow[0].webserver_url : null
}

output "mwaa_security_group_id" {
  description = "Security group ID for MWAA"
  value       = var.enable_mwaa ? aws_security_group.mwaa_sg[0].id : null
}

# CloudWatch Log Groups
output "lambda_log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "lambda_log_group_arn" {
  description = "ARN of the Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "step_functions_log_group_name" {
  description = "Name of the Step Functions CloudWatch log group"
  value       = var.enable_step_functions ? aws_cloudwatch_log_group.step_functions_logs[0].name : null
}

output "step_functions_log_group_arn" {
  description = "ARN of the Step Functions CloudWatch log group"
  value       = var.enable_step_functions ? aws_cloudwatch_log_group.step_functions_logs[0].arn : null
} 