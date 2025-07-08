# =============================================================================
# Security Module - IAM Roles, KMS Keys, and Security Policies
# =============================================================================

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# KMS Keys for Data Encryption
# =============================================================================

# Main data encryption key
resource "aws_kms_key" "data_key" {
  description             = "KMS key for ${var.project_name} data encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow data platform services"
        Effect = "Allow"
        Principal = {
          Service = [
            "s3.amazonaws.com",
            "lambda.amazonaws.com",
            "glue.amazonaws.com",
            "kinesis.amazonaws.com",
            "states.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncrypt*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_kms_alias" "data_key" {
  name          = "alias/${var.project_name}-data-key"
  target_key_id = aws_kms_key.data_key.key_id
}

# Secrets encryption key
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for ${var.project_name} secrets encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  tags = var.common_tags
}

resource "aws_kms_alias" "secrets_key" {
  name          = "alias/${var.project_name}-secrets-key"
  target_key_id = aws_kms_key.secrets_key.key_id
}

# =============================================================================
# IAM Roles for Data Platform Services
# =============================================================================

# Glue service role
resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Kinesis Analytics role
resource "aws_iam_role" "kinesis_analytics_role" {
  name = "${var.project_name}-kinesis-analytics-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "kinesisanalytics.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# =============================================================================
# IAM Policies for Data Platform Operations
# =============================================================================

# S3 data access policy
resource "aws_iam_policy" "s3_data_access" {
  name = "${var.project_name}-s3-data-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.data_key.arn
      }
    ]
  })

  tags = var.common_tags
}

# Glue data catalog access policy
resource "aws_iam_policy" "glue_catalog_access" {
  name = "${var.project_name}-glue-catalog-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

# Kinesis access policy
resource "aws_iam_policy" "kinesis_access" {
  name = "${var.project_name}-kinesis-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ]
        Resource = "arn:aws:kinesis:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stream/${var.project_name}-*"
      }
    ]
  })

  tags = var.common_tags
}

# =============================================================================
# Security Groups
# =============================================================================

# Data processing security group
resource "aws_security_group" "data_processing_sg" {
  name_prefix = "${var.project_name}-data-processing-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS API calls"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-data-processing-sg"
  })
}

# =============================================================================
# IAM Role Policy Attachments
# =============================================================================

resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.s3_data_access.arn
}

resource "aws_iam_role_policy_attachment" "glue_catalog_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_catalog_access.arn
} 