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
output "glue_role_arn" {
  description = "ARN of the Glue service role"
  value       = aws_iam_role.glue_role.arn
}

output "glue_role_name" {
  description = "Name of the Glue service role"
  value       = aws_iam_role.glue_role.name
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