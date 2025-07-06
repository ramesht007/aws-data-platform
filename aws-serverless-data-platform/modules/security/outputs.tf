# =============================================================================
# Security Module Outputs
# =============================================================================

# KMS Key Outputs
output "data_kms_key_id" {
  description = "ID of the data encryption KMS key"
  value       = aws_kms_key.data_key.key_id
}

output "data_kms_key_arn" {
  description = "ARN of the data encryption KMS key"
  value       = aws_kms_key.data_key.arn
}

output "secrets_kms_key_id" {
  description = "ID of the secrets encryption KMS key"
  value       = aws_kms_key.secrets_key.key_id
}

output "secrets_kms_key_arn" {
  description = "ARN of the secrets encryption KMS key"
  value       = aws_kms_key.secrets_key.arn
}

# IAM Role Outputs
output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_role.name
}

output "glue_role_arn" {
  description = "ARN of the Glue service role"
  value       = aws_iam_role.glue_role.arn
}

output "glue_role_name" {
  description = "Name of the Glue service role"
  value       = aws_iam_role.glue_role.name
}

output "kinesis_analytics_role_arn" {
  description = "ARN of the Kinesis Analytics role"
  value       = aws_iam_role.kinesis_analytics_role.arn
}

output "kinesis_analytics_role_name" {
  description = "Name of the Kinesis Analytics role"
  value       = aws_iam_role.kinesis_analytics_role.name
}

output "step_functions_role_arn" {
  description = "ARN of the Step Functions role"
  value       = aws_iam_role.step_functions_role.arn
}

output "step_functions_role_name" {
  description = "Name of the Step Functions role"
  value       = aws_iam_role.step_functions_role.name
}

# Security Group Outputs
output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

output "data_processing_security_group_id" {
  description = "ID of the data processing security group"
  value       = aws_security_group.data_processing_sg.id
}

# Policy Outputs
output "s3_data_access_policy_arn" {
  description = "ARN of the S3 data access policy"
  value       = aws_iam_policy.s3_data_access.arn
}

output "glue_catalog_access_policy_arn" {
  description = "ARN of the Glue catalog access policy"
  value       = aws_iam_policy.glue_catalog_access.arn
}

output "kinesis_access_policy_arn" {
  description = "ARN of the Kinesis access policy"
  value       = aws_iam_policy.kinesis_access.arn
} 