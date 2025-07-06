# =============================================================================
# Streaming Module - Kinesis Data Streams, Analytics, and Real-time Processing
# =============================================================================

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Kinesis Data Streams
# =============================================================================

# Main data stream
resource "aws_kinesis_stream" "data_stream" {
  name        = "${var.project_name}-${var.environment}-data-stream"
  shard_count = var.shard_count

  retention_period = var.retention_period

  shard_level_metrics = [
    "IncomingRecords",
    "OutgoingRecords",
  ]

  stream_mode_details {
    stream_mode = var.stream_mode
  }

  encryption_type = "KMS"
  kms_key_id      = var.kms_key_id

  tags = var.common_tags
}

# Error stream for failed records
resource "aws_kinesis_stream" "error_stream" {
  name        = "${var.project_name}-${var.environment}-error-stream"
  shard_count = 1

  retention_period = var.retention_period

  encryption_type = "KMS"
  kms_key_id      = var.kms_key_id

  tags = var.common_tags
}

# =============================================================================
# Kinesis Data Firehose Delivery Streams
# =============================================================================

# S3 delivery stream for data lake
resource "aws_kinesis_firehose_delivery_stream" "s3_delivery" {
  name        = "${var.project_name}-${var.environment}-s3-delivery"
  destination = "s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.data_stream.arn
    role_arn           = var.firehose_role_arn
  }

  s3_configuration {
    role_arn           = var.firehose_role_arn
    bucket_arn         = var.raw_data_bucket_arn
    prefix             = "streaming-data/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/"
    buffer_size        = var.buffer_size
    buffer_interval    = var.buffer_interval
    compression_format = "GZIP"

    # Data transformation
    processing_configuration {
      enabled = var.enable_data_transformation

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = var.transformation_lambda_arn
        }
      }
    }

    # CloudWatch logging
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = "S3Delivery"
    }
  }

  tags = var.common_tags

  depends_on = [aws_kinesis_stream.data_stream]
}

# OpenSearch delivery stream for analytics
resource "aws_kinesis_firehose_delivery_stream" "opensearch_delivery" {
  count = var.enable_opensearch_delivery ? 1 : 0

  name        = "${var.project_name}-${var.environment}-opensearch-delivery"
  destination = "opensearch"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.data_stream.arn
    role_arn           = var.firehose_role_arn
  }

  opensearch_configuration {
    domain_arn            = var.opensearch_domain_arn
    role_arn              = var.firehose_role_arn
    index_name            = "${var.project_name}-${var.environment}"
    index_rotation_period = "OneDay"
    buffering_size        = var.buffer_size
    buffering_interval    = var.buffer_interval

    # Backup to S3
    s3_backup_mode = "AllDocuments"

    s3_configuration {
      role_arn           = var.firehose_role_arn
      bucket_arn         = var.raw_data_bucket_arn
      prefix             = "opensearch-backup/"
      buffer_size        = 5
      buffer_interval    = 300
      compression_format = "GZIP"
    }

    # CloudWatch logging
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = "OpensearchDelivery"
    }
  }

  tags = var.common_tags
}

# =============================================================================
# Kinesis Analytics Application (SQL-based)
# =============================================================================

resource "aws_kinesis_analytics_application" "real_time_analytics" {
  count = var.enable_analytics_application ? 1 : 0

  name = "${var.project_name}-${var.environment}-analytics"

  application_code = file("${path.module}/sql/real_time_analytics.sql")

  inputs {
    name_prefix = "SOURCE_SQL_STREAM"

    kinesis_stream {
      resource_arn = aws_kinesis_stream.data_stream.arn
      role_arn     = var.analytics_role_arn
    }

    parallelism {
      count = 1
    }

    schema {
      record_columns {
        mapping  = "$.user_id"
        name     = "user_id"
        sql_type = "VARCHAR(32)"
      }

      record_columns {
        mapping  = "$.event_type"
        name     = "event_type"
        sql_type = "VARCHAR(64)"
      }

      record_columns {
        mapping  = "$.timestamp"
        name     = "timestamp"
        sql_type = "TIMESTAMP"
      }

      record_format {
        record_format_type = "JSON"

        mapping_parameters {
          json_mapping_parameters {
            record_row_path = "$"
          }
        }
      }
    }
  }

  outputs {
    name = "DESTINATION_SQL_STREAM"

    kinesis_stream {
      resource_arn = aws_kinesis_stream.processed_stream[0].arn
      role_arn     = var.analytics_role_arn
    }

    schema {
      record_format_type = "JSON"
    }
  }

  tags = var.common_tags
}

# Processed stream for analytics output
resource "aws_kinesis_stream" "processed_stream" {
  count = var.enable_analytics_application ? 1 : 0

  name        = "${var.project_name}-${var.environment}-processed-stream"
  shard_count = 1

  retention_period = var.retention_period

  encryption_type = "KMS"
  kms_key_id      = var.kms_key_id

  tags = var.common_tags
}

# =============================================================================
# MSK (Managed Streaming for Apache Kafka) - Optional
# =============================================================================

resource "aws_msk_cluster" "kafka_cluster" {
  count = var.enable_msk ? 1 : 0

  cluster_name           = "${var.project_name}-${var.environment}-kafka"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.kafka_instance_type
    client_subnets  = var.kafka_subnet_ids
    security_groups = [aws_security_group.msk_sg[0].id]

    storage_info {
      ebs_storage_info {
        volume_size = var.kafka_volume_size
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_id = var.kms_key_id
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_logs[0].name
      }
      s3 {
        enabled = true
        bucket  = var.logs_bucket_name
        prefix  = "msk-logs/"
      }
    }
  }

  tags = var.common_tags
}

# MSK Security Group
resource "aws_security_group" "msk_sg" {
  count = var.enable_msk ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-msk-"
  vpc_id      = var.vpc_id

  # Kafka port
  ingress {
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [var.lambda_security_group_id]
    description     = "Kafka SASL/IAM"
  }

  # Zookeeper port
  ingress {
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [var.lambda_security_group_id]
    description     = "Zookeeper"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-msk-sg"
  })
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "firehose_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "msk_logs" {
  count = var.enable_msk ? 1 : 0

  name              = "/aws/msk/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "kinesis_analytics_logs" {
  count = var.enable_analytics_application ? 1 : 0

  name              = "/aws/kinesis-analytics/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

# =============================================================================
# CloudWatch Alarms for Monitoring
# =============================================================================

# High incoming records alarm
resource "aws_cloudwatch_metric_alarm" "high_incoming_records" {
  alarm_name          = "${var.project_name}-${var.environment}-kinesis-high-incoming-records"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "IncomingRecords"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.high_incoming_records_threshold
  alarm_description   = "This metric monitors kinesis incoming records"

  dimensions = {
    StreamName = aws_kinesis_stream.data_stream.name
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.common_tags
}

# Iterator age alarm
resource "aws_cloudwatch_metric_alarm" "iterator_age" {
  alarm_name          = "${var.project_name}-${var.environment}-kinesis-iterator-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Maximum"
  threshold           = var.iterator_age_threshold
  alarm_description   = "This metric monitors kinesis iterator age"

  dimensions = {
    StreamName = aws_kinesis_stream.data_stream.name
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.common_tags
} 