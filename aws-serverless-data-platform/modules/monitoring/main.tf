# =============================================================================
# Monitoring Module - CloudWatch, SNS, and Platform Monitoring
# =============================================================================

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# SNS Topics for Notifications
# =============================================================================

# Critical alerts topic
resource "aws_sns_topic" "critical_alerts" {
  name              = "${var.project_name}-${var.environment}-critical-alerts"
  kms_master_key_id = var.kms_key_id

  tags = var.common_tags
}

# Warning alerts topic
resource "aws_sns_topic" "warning_alerts" {
  name              = "${var.project_name}-${var.environment}-warning-alerts"
  kms_master_key_id = var.kms_key_id

  tags = var.common_tags
}

# Data quality alerts topic
resource "aws_sns_topic" "data_quality_alerts" {
  name              = "${var.project_name}-${var.environment}-data-quality-alerts"
  kms_master_key_id = var.kms_key_id

  tags = var.common_tags
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "critical_email" {
  count = length(var.critical_alert_emails)

  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.critical_alert_emails[count.index]
}

resource "aws_sns_topic_subscription" "warning_email" {
  count = length(var.warning_alert_emails)

  topic_arn = aws_sns_topic.warning_alerts.arn
  protocol  = "email"
  endpoint  = var.warning_alert_emails[count.index]
}

# =============================================================================
# CloudWatch Log Groups for Centralized Logging
# =============================================================================

resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/dataplatform/${var.project_name}/${var.environment}/application"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "error_logs" {
  name              = "/aws/dataplatform/${var.project_name}/${var.environment}/errors"
  retention_in_days = var.error_log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "audit_logs" {
  name              = "/aws/dataplatform/${var.project_name}/${var.environment}/audit"
  retention_in_days = var.audit_log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.common_tags
}

# =============================================================================
# CloudWatch Metric Filters
# =============================================================================

# Error metric filter
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-${var.environment}-error-count"
  log_group_name = aws_cloudwatch_log_group.error_logs.name
  pattern        = "[timestamp, request_id, ERROR, ...]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/${var.environment}/Application"
    value     = "1"
  }
}

# Warning metric filter
resource "aws_cloudwatch_log_metric_filter" "warning_count" {
  name           = "${var.project_name}-${var.environment}-warning-count"
  log_group_name = aws_cloudwatch_log_group.application_logs.name
  pattern        = "[timestamp, request_id, WARN, ...]"

  metric_transformation {
    name      = "WarningCount"
    namespace = "${var.project_name}/${var.environment}/Application"
    value     = "1"
  }
}

# Data quality metric filter
resource "aws_cloudwatch_log_metric_filter" "data_quality_issues" {
  name           = "${var.project_name}-${var.environment}-data-quality-issues"
  log_group_name = aws_cloudwatch_log_group.application_logs.name
  pattern        = "[timestamp, request_id, DATA_QUALITY_ISSUE, ...]"

  metric_transformation {
    name      = "DataQualityIssues"
    namespace = "${var.project_name}/${var.environment}/DataQuality"
    value     = "1"
  }
}

# =============================================================================
# CloudWatch Alarms
# =============================================================================

# High error rate alarm
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorCount"
  namespace           = "${var.project_name}/${var.environment}/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This metric monitors application error rate"
  alarm_actions       = [aws_sns_topic.critical_alerts.arn]
  ok_actions          = [aws_sns_topic.critical_alerts.arn]

  tags = var.common_tags
}

# Data quality issues alarm
resource "aws_cloudwatch_metric_alarm" "data_quality_issues" {
  alarm_name          = "${var.project_name}-${var.environment}-data-quality-issues"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DataQualityIssues"
  namespace           = "${var.project_name}/${var.environment}/DataQuality"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.data_quality_threshold
  alarm_description   = "This metric monitors data quality issues"
  alarm_actions       = [aws_sns_topic.data_quality_alerts.arn]

  tags = var.common_tags
}

# Lambda function errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = length(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors-${var.lambda_function_names[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Lambda function errors"

  dimensions = {
    FunctionName = var.lambda_function_names[count.index]
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.critical_alerts.arn]

  tags = var.common_tags
}

# =============================================================================
# CloudWatch Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-monitoring"

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
            ["${var.project_name}/${var.environment}/Application", "ErrorCount"],
            [".", "WarningCount"],
            ["${var.project_name}/${var.environment}/DataQuality", "DataQualityIssues"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Application Health Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = concat([
            for func_name in var.lambda_function_names : [
              "AWS/Lambda", "Duration", "FunctionName", func_name
            ]
          ])
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Function Performance"
          period  = 300
        }
      }
    ]
  })
} 