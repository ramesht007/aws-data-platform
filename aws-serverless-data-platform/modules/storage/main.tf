# =============================================================================
# Storage Module
# Creates S3 buckets for data lake layers with lifecycle policies and security
# =============================================================================

# Local variables for bucket naming
locals {
  bucket_suffix = "${var.environment}-${var.region}-${random_id.bucket_suffix.hex}"
  
  # Common S3 bucket configuration
  bucket_config = {
    versioning              = var.storage.s3.versioning
    encryption              = var.storage.s3.encryption
    public_access_block     = var.storage.s3.public_access_block
    force_destroy           = var.storage.s3.force_destroy
  }
}

# Random ID for bucket uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# KMS Key for S3 encryption
resource "aws_kms_key" "s3" {
  description         = "KMS key for S3 bucket encryption in ${var.environment}"
  deletion_window_in_days = var.security.kms.deletion_window
  enable_key_rotation = var.security.kms.enable_key_rotation

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "kms-s3-${var.environment}-${var.region}"
    Type = "kms-key"
    Purpose = "s3-encryption"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "s3" {
  name          = "alias/s3-${var.environment}-${var.region}"
  target_key_id = aws_kms_key.s3.key_id
}

# Raw Data Bucket
resource "aws_s3_bucket" "raw" {
  bucket        = "${var.raw_bucket_name}-${local.bucket_suffix}"
  force_destroy = local.bucket_config.force_destroy

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "${var.raw_bucket_name}-${local.bucket_suffix}"
    Type = "s3-bucket"
    Layer = "raw"
    Purpose = "raw-data-storage"
  })
}

# Processed Data Bucket
resource "aws_s3_bucket" "processed" {
  bucket        = "${var.processed_bucket_name}-${local.bucket_suffix}"
  force_destroy = local.bucket_config.force_destroy

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "${var.processed_bucket_name}-${local.bucket_suffix}"
    Type = "s3-bucket"
    Layer = "processed"
    Purpose = "processed-data-storage"
  })
}

# Curated Data Bucket
resource "aws_s3_bucket" "curated" {
  bucket        = "${var.curated_bucket_name}-${local.bucket_suffix}"
  force_destroy = local.bucket_config.force_destroy

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "${var.curated_bucket_name}-${local.bucket_suffix}"
    Type = "s3-bucket"
    Layer = "curated"
    Purpose = "curated-data-storage"
  })
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration {
    status = local.bucket_config.versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = local.bucket_config.versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "curated" {
  bucket = aws_s3_bucket.curated.id
  versioning_configuration {
    status = local.bucket_config.versioning ? "Enabled" : "Disabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.bucket_config.encryption == "aws:kms" ? aws_kms_key.s3.arn : null
      sse_algorithm     = local.bucket_config.encryption == "aws:kms" ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = local.bucket_config.encryption == "aws:kms"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.bucket_config.encryption == "aws:kms" ? aws_kms_key.s3.arn : null
      sse_algorithm     = local.bucket_config.encryption == "aws:kms" ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = local.bucket_config.encryption == "aws:kms"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.bucket_config.encryption == "aws:kms" ? aws_kms_key.s3.arn : null
      sse_algorithm     = local.bucket_config.encryption == "aws:kms" ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = local.bucket_config.encryption == "aws:kms"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = local.bucket_config.public_access_block
  block_public_policy     = local.bucket_config.public_access_block
  ignore_public_acls      = local.bucket_config.public_access_block
  restrict_public_buckets = local.bucket_config.public_access_block
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = local.bucket_config.public_access_block
  block_public_policy     = local.bucket_config.public_access_block
  ignore_public_acls      = local.bucket_config.public_access_block
  restrict_public_buckets = local.bucket_config.public_access_block
}

resource "aws_s3_bucket_public_access_block" "curated" {
  bucket = aws_s3_bucket.curated.id

  block_public_acls       = local.bucket_config.public_access_block
  block_public_policy     = local.bucket_config.public_access_block
  ignore_public_acls      = local.bucket_config.public_access_block
  restrict_public_buckets = local.bucket_config.public_access_block
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "raw_data_lifecycle"
    status = "Enabled"

    transition {
      days          = var.storage.lifecycle.transition_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.storage.lifecycle.transition_glacier_days
      storage_class = "GLACIER"
    }

    transition {
      days          = var.storage.lifecycle.transition_deep_archive_days
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = var.storage.lifecycle.expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    id     = "processed_data_lifecycle"
    status = "Enabled"

    transition {
      days          = var.storage.lifecycle.transition_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.storage.lifecycle.transition_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.storage.lifecycle.expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id

  rule {
    id     = "curated_data_lifecycle"
    status = "Enabled"

    transition {
      days          = var.storage.lifecycle.transition_ia_days * 2  # Keep curated data longer in standard
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.storage.lifecycle.transition_glacier_days * 2
      storage_class = "GLACIER"
    }

    expiration {
      days = var.storage.lifecycle.expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 90  # Longer retention for curated data versions
    }
  }
}

# S3 Bucket Notification for EventBridge
resource "aws_s3_bucket_notification" "raw" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true
}

resource "aws_s3_bucket_notification" "processed" {
  bucket      = aws_s3_bucket.processed.id
  eventbridge = true
}

resource "aws_s3_bucket_notification" "curated" {
  bucket      = aws_s3_bucket.curated.id
  eventbridge = true
}

# =============================================================================
# Data Catalog Module - AWS Glue Database, Crawlers, and Catalog Management
# =============================================================================

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Glue Catalog Database
# =============================================================================

resource "aws_glue_catalog_database" "main" {
  name        = "${var.project_name}_${var.environment}"
  description = "Main data catalog database for ${var.project_name} in ${var.environment}"

  catalog_id = data.aws_caller_identity.current.account_id

  tags = var.common_tags
}

# Raw data database
resource "aws_glue_catalog_database" "raw" {
  name        = "${var.project_name}_${var.environment}_raw"
  description = "Raw data catalog database for ${var.project_name} in ${var.environment}"

  catalog_id = data.aws_caller_identity.current.account_id

  tags = var.common_tags
}

# Processed data database
resource "aws_glue_catalog_database" "processed" {
  name        = "${var.project_name}_${var.environment}_processed"
  description = "Processed data catalog database for ${var.project_name} in ${var.environment}"

  catalog_id = data.aws_caller_identity.current.account_id

  tags = var.common_tags
}

# Curated data database
resource "aws_glue_catalog_database" "curated" {
  name        = "${var.project_name}_${var.environment}_curated"
  description = "Curated data catalog database for ${var.project_name} in ${var.environment}"

  catalog_id = data.aws_caller_identity.current.account_id

  tags = var.common_tags
}

# =============================================================================
# CloudWatch Log Group
# =============================================================================

resource "aws_cloudwatch_log_group" "glue_logs" {
  name              = "/aws-glue/jobs/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}