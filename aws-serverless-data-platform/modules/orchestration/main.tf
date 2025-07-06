# =============================================================================
# Orchestration Module - Step Functions, Lambda, and MWAA
# =============================================================================

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# MWAA (Managed Apache Airflow) Environment
# =============================================================================

resource "aws_mwaa_environment" "airflow" {
  count = var.enable_mwaa ? 1 : 0

  name                 = "${var.project_name}-${var.environment}-airflow"
  airflow_version      = var.airflow_version
  environment_class    = var.airflow_environment_class
  max_workers          = var.airflow_max_workers
  min_workers          = var.airflow_min_workers
  schedulers           = var.airflow_schedulers

  dag_s3_path          = "dags/"
  requirements_s3_path = "requirements.txt"
  plugins_s3_path      = "plugins.zip"

  source_bucket_arn    = var.airflow_s3_bucket_arn
  execution_role_arn   = var.mwaa_execution_role_arn

  network_configuration {
    security_group_ids = [aws_security_group.mwaa_sg[0].id]
    subnet_ids         = var.mwaa_subnet_ids
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }
    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  airflow_configuration_options = var.airflow_configuration_options

  tags = var.common_tags
}

# MWAA Security Group
resource "aws_security_group" "mwaa_sg" {
  count = var.enable_mwaa ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-mwaa-"
  vpc_id      = var.vpc_id

  # Self-referencing rule for MWAA
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-sg"
  })
}