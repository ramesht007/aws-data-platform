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

  # create_table_default_permission {
  #   permissions = ["ALL"]
  #   principal {
  #     data_lake_principal_identifier = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.glue_role_name}"
  #   }
  # }

  tags = var.common_tags
}

# Raw data database
resource "aws_glue_catalog_database" "raw" {
  name        = "${var.project_name}_${var.environment}_raw"
  description = "Raw data catalog database for ${var.project_name} in ${var.environment}"

  catalog_id = data.aws_caller_identity.current.account_id

  # create_table_default_permission {
  #   permissions = ["ALL"]
  #   principal {
  #     data_lake_principal_identifier = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.glue_role_name}"
  #   }
  # }

  tags = var.common_tags
}

# Processed data database
resource "aws_glue_catalog_database" "processed" {
  name        = "${var.project_name}_${var.environment}_processed"
  description = "Processed data catalog database for ${var.project_name} in ${var.environment}"

  catalog_id = data.aws_caller_identity.current.account_id

  # create_table_default_permission {
  #   permissions = ["ALL"]
  #   principal {
  #     data_lake_principal_identifier = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.glue_role_name}"
  #   }
  # }

  tags = var.common_tags
}

# Curated data database
resource "aws_glue_catalog_database" "curated" {
  name        = "${var.project_name}_${var.environment}_curated"
  description = "Curated data catalog database for ${var.project_name} in ${var.environment}"

  catalog_id = data.aws_caller_identity.current.account_id

  # create_table_default_permission {
  #   permissions = ["ALL"]
  #   principal {
  #     data_lake_principal_identifier = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.glue_role_name}"
  #   }
  # }

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