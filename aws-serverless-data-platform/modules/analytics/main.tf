# =============================================================================
# Analytics Module - Athena, QuickSight, and OpenSearch
# =============================================================================

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# =============================================================================
# Amazon Athena Configuration
# =============================================================================

# Athena workgroup
resource "aws_athena_workgroup" "main" {
  name = "${var.project_name}-${var.environment}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics        = true
    bytes_scanned_cutoff_per_query     = var.bytes_scanned_cutoff_per_query
    result_configuration_updates_enabled = false

    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_id        = var.kms_key_id
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }

  force_destroy = var.environment != "prod"

  tags = var.common_tags
}

# Athena named queries for common use cases
resource "aws_athena_named_query" "sample_analytics" {
  count = var.create_sample_queries ? 1 : 0

  name      = "${var.project_name}_${var.environment}_user_analytics"
  workgroup = aws_athena_workgroup.main.name
  database  = var.glue_database_name
  
  query = <<EOF
-- User Analytics Query
-- Analyze user behavior patterns from event data
SELECT 
    user_id,
    event_type,
    DATE(timestamp) as event_date,
    COUNT(*) as event_count,
    COUNT(DISTINCT DATE(timestamp)) as active_days
FROM user_events
WHERE 
    year = '2023' 
    AND month = '12'
GROUP BY 
    user_id, 
    event_type, 
    DATE(timestamp)
ORDER BY 
    event_count DESC
LIMIT 100;
EOF

  description = "Analyze user behavior patterns from event data"
}

resource "aws_athena_named_query" "data_quality_check" {
  count = var.create_sample_queries ? 1 : 0

  name      = "${var.project_name}_${var.environment}_data_quality"
  workgroup = aws_athena_workgroup.main.name
  database  = var.glue_database_name
  
  query = <<EOF
-- Data Quality Check Query
-- Identify data quality issues in the dataset
SELECT 
    'null_user_ids' as check_type,
    COUNT(*) as issue_count
FROM user_events
WHERE user_id IS NULL

UNION ALL

SELECT 
    'null_timestamps' as check_type,
    COUNT(*) as issue_count
FROM user_events
WHERE timestamp IS NULL

UNION ALL

SELECT 
    'future_timestamps' as check_type,
    COUNT(*) as issue_count
FROM user_events
WHERE timestamp > CURRENT_TIMESTAMP

UNION ALL

SELECT 
    'duplicate_events' as check_type,
    COUNT(*) - COUNT(DISTINCT user_id, event_type, timestamp) as issue_count
FROM user_events;
EOF

  description = "Identify data quality issues in the dataset"
}

# =============================================================================
# Amazon OpenSearch Service
# =============================================================================

resource "aws_opensearch_domain" "main" {
  count = var.enable_opensearch ? 1 : 0

  domain_name    = "${var.project_name}-${var.environment}-search"
  engine_version = var.opensearch_version

  cluster_config {
    instance_type            = var.opensearch_instance_type
    instance_count           = var.opensearch_instance_count
    dedicated_master_enabled = var.opensearch_dedicated_master_enabled
    dedicated_master_type    = var.opensearch_dedicated_master_type
    dedicated_master_count   = var.opensearch_dedicated_master_count
    zone_awareness_enabled   = var.opensearch_zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.opensearch_zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.opensearch_availability_zone_count
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.opensearch_ebs_volume_size
    throughput  = 125
    iops        = 3000
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_id
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  vpc_options {
    subnet_ids         = var.opensearch_subnet_ids
    security_group_ids = [aws_security_group.opensearch_sg[0].id]
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true
    
    master_user_options {
      master_user_name     = var.opensearch_master_user_name
      master_user_password = var.opensearch_master_user_password
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs[0].arn
    log_type                 = "INDEX_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs[0].arn
    log_type                 = "SEARCH_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs[0].arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }

  tags = var.common_tags

  depends_on = [aws_iam_service_linked_role.opensearch]
}

# OpenSearch Service Linked Role
resource "aws_iam_service_linked_role" "opensearch" {
  count = var.enable_opensearch ? 1 : 0

  aws_service_name = "opensearchservice.amazonaws.com"
  description      = "Service linked role for OpenSearch"
}

# OpenSearch Security Group
resource "aws_security_group" "opensearch_sg" {
  count = var.enable_opensearch ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-opensearch-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.opensearch_allowed_cidr_blocks
    description = "HTTPS access to OpenSearch"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-opensearch-sg"
  })
}

# OpenSearch Domain Policy
resource "aws_opensearch_domain_policy" "main" {
  count = var.enable_opensearch ? 1 : 0

  domain_name = aws_opensearch_domain.main[0].domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = "${aws_opensearch_domain.main[0].arn}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.opensearch_allowed_cidr_blocks
          }
        }
      }
    ]
  })
}

# =============================================================================
# Amazon QuickSight Configuration
# =============================================================================

# QuickSight data source for Athena
resource "aws_quicksight_data_source" "athena" {
  count = var.enable_quicksight ? 1 : 0

  data_source_id = "${var.project_name}-${var.environment}-athena-source"
  name           = "${var.project_name} ${var.environment} Athena Data Source"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = aws_athena_workgroup.main.name
    }
  }

  permission {
    principal = data.aws_caller_identity.current.arn
    actions = [
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:DeleteDataSource",
      "quicksight:UpdateDataSourcePermissions"
    ]
  }

  tags = var.common_tags
}

# QuickSight dataset
resource "aws_quicksight_data_set" "user_analytics" {
  count = var.enable_quicksight && var.create_sample_datasets ? 1 : 0

  data_set_id = "${var.project_name}-${var.environment}-user-analytics"
  name        = "${var.project_name} ${var.environment} User Analytics"

  physical_table_map {
    physical_table_id = "user_events_table"
    relational_table {
      data_source_arn = aws_quicksight_data_source.athena[0].arn
      catalog         = "AwsDataCatalog"
      schema          = var.glue_database_name
      name            = "user_events"

      input_columns {
        name = "user_id"
        type = "STRING"
      }
      input_columns {
        name = "event_type"
        type = "STRING"
      }
      input_columns {
        name = "timestamp"
        type = "DATETIME"
      }
      input_columns {
        name = "properties"
        type = "STRING"
      }
    }
  }

  tags = var.common_tags
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "athena_logs" {
  name              = "/aws/athena/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "opensearch_logs" {
  count = var.enable_opensearch ? 1 : 0

  name              = "/aws/opensearch/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

# =============================================================================
# CloudWatch Dashboards
# =============================================================================

resource "aws_cloudwatch_dashboard" "analytics_dashboard" {
  count = var.create_cloudwatch_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-analytics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Athena", "QueryExecutionTime", "WorkGroup", aws_athena_workgroup.main.name],
            [".", "ProcessedBytes", ".", "."],
            [".", "QueryQueueTime", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Athena Query Performance"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = var.enable_opensearch ? [
            ["AWS/ES", "SearchLatency", "DomainName", aws_opensearch_domain.main[0].domain_name, "ClientId", data.aws_caller_identity.current.account_id],
            [".", "IndexingLatency", ".", ".", ".", "."],
            [".", "CPUUtilization", ".", ".", ".", "."],
            [".", "JVMMemoryPressure", ".", ".", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "OpenSearch Performance"
          period  = 300
        }
      }
    ]
  })
} 