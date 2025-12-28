# ============================================================================
# Terraform Module: Monitoring & Alerting
# ============================================================================
# This module creates CloudWatch alarms and SNS topics for incident response
# automation and alerting.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# SNS Topic for Critical Incidents
# ============================================================================

resource "aws_sns_topic" "incident_critical" {
  name              = "${var.project}-${var.environment}-incident-critical"
  display_name      = "Critical Incidents - ${var.environment}"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(var.tags, {
    Name     = "${var.project}-${var.environment}-incident-critical"
    Severity = "P0-P1"
  })
}

resource "aws_sns_topic" "incident_warning" {
  name              = "${var.project}-${var.environment}-incident-warning"
  display_name      = "Warning Level Incidents - ${var.environment}"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(var.tags, {
    Name     = "${var.project}-${var.environment}-incident-warning"
    Severity = "P2-P3"
  })
}

# ============================================================================
# SNS Subscriptions
# ============================================================================

resource "aws_sns_topic_subscription" "critical_email" {
  for_each = toset(var.critical_notification_emails)

  topic_arn = aws_sns_topic.incident_critical.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "warning_email" {
  for_each = toset(var.warning_notification_emails)

  topic_arn = aws_sns_topic.incident_warning.arn
  protocol  = "email"
  endpoint  = each.value
}

# ============================================================================
# CloudWatch Log Groups for Incident Response Scripts
# ============================================================================

resource "aws_cloudwatch_log_group" "incident_response" {
  # checkov:skip=CKV_AWS_338:Ensure CloudWatch log groups retains logs for at least 1 year|30 days is ok for demo
  name              = "/aws/incident-response/${var.project}-${var.environment}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-incident-response-logs"
  })
}

# ============================================================================
# CloudWatch Composite Alarms
# ============================================================================
# Composite alarms combine multiple alarms for better signal-to-noise ratio

resource "aws_cloudwatch_composite_alarm" "api_health" {
  alarm_name                = "${var.project}-${var.environment}-api-health-critical"
  alarm_description         = "Critical: Multiple API health indicators are failing"
  actions_enabled           = true
  alarm_actions             = [aws_sns_topic.incident_critical.arn]
  ok_actions                = [aws_sns_topic.incident_critical.arn]
  insufficient_data_actions = []

  # Trigger if ANY of these conditions are true (OR logic)
  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.api_5xx_errors.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.lambda_errors_high.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name})"
  ])

  tags = var.tags
}

# ============================================================================
# API Gateway Alarms
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.project}-${var.environment}-api-5xx-errors"
  alarm_description   = "API Gateway 5xx error rate is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  dimensions = {
    ApiName = var.api_name
    Stage   = var.environment
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${var.project}-${var.environment}-api-4xx-errors"
  alarm_description   = "API Gateway 4xx error rate is too high (potential abuse)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 100 # High threshold as 4xx can be normal
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_warning.arn]

  dimensions = {
    ApiName = var.api_name
    Stage   = var.environment
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.project}-${var.environment}-api-latency-high"
  alarm_description   = "API Gateway latency is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Average"
  threshold           = 3000 # 3 seconds
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_warning.arn]

  dimensions = {
    ApiName = var.api_name
    Stage   = var.environment
  }

  tags = var.tags
}

# ============================================================================
# Lambda Alarms (Aggregated across all functions)
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors_high" {
  alarm_name          = "${var.project}-${var.environment}-lambda-errors-high"
  alarm_description   = "Lambda error rate is critically high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project}-${var.environment}-lambda-duration-warning"
  alarm_description   = "Lambda execution duration approaching timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 8000 # 8 seconds (80% of 10s timeout)
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_warning.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project}-${var.environment}-lambda-throttles"
  alarm_description   = "Lambda functions are being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  alarm_name          = "${var.project}-${var.environment}-lambda-concurrent-high"
  alarm_description   = "Lambda concurrent executions are too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = 50
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_warning.arn]

  tags = var.tags
}

# ============================================================================
# Lambda Function-Specific Alarms
# ============================================================================
# These alarms monitor individual Lambda functions (replaces SAM template alarms)
# Now with proper SNS notifications!

resource "aws_cloudwatch_metric_alarm" "lambda_function_errors" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project}-${var.environment}-lambda-${each.key}-errors"
  alarm_description   = "Lambda function ${each.key} is experiencing errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]
  ok_actions          = [aws_sns_topic.incident_critical.arn]

  dimensions = {
    FunctionName = each.key
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_function_duration" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project}-${var.environment}-lambda-${each.key}-duration"
  alarm_description   = "Lambda function ${each.key} execution duration approaching timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 8000 # 80% of 10s default timeout
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_warning.arn]

  dimensions = {
    FunctionName = each.key
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_function_throttles" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project}-${var.environment}-lambda-${each.key}-throttles"
  alarm_description   = "Lambda function ${each.key} is being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  dimensions = {
    FunctionName = each.key
  }

  tags = var.tags
}

# ============================================================================
# DynamoDB Alarms
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttle" {
  count = length(var.dynamodb_table_names)

  alarm_name          = "${var.project}-${var.environment}-dynamodb-read-throttle-${var.dynamodb_table_names[count.index]}"
  alarm_description   = "DynamoDB table ${var.dynamodb_table_names[count.index]} is experiencing read throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  dimensions = {
    TableName = var.dynamodb_table_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttle" {
  count = length(var.dynamodb_table_names)

  alarm_name          = "${var.project}-${var.environment}-dynamodb-write-throttle-${var.dynamodb_table_names[count.index]}"
  alarm_description   = "DynamoDB table ${var.dynamodb_table_names[count.index]} is experiencing write throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  dimensions = {
    TableName = var.dynamodb_table_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_system_errors" {
  count = length(var.dynamodb_table_names)

  alarm_name          = "${var.project}-${var.environment}-dynamodb-system-errors-${var.dynamodb_table_names[count.index]}"
  alarm_description   = "DynamoDB table ${var.dynamodb_table_names[count.index]} is experiencing system errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  dimensions = {
    TableName = var.dynamodb_table_names[count.index]
  }

  tags = var.tags
}

# ============================================================================
# Cognito Alarms
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "cognito_user_auth_errors" {
  count = var.enable_cognito_alarms ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-cognito-auth-errors"
  alarm_description   = "High rate of Cognito authentication failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UserAuthenticationErrors"
  namespace           = "AWS/Cognito"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_warning.arn]

  dimensions = {
    UserPool = var.cognito_user_pool_id
  }

  tags = var.tags
}

# ============================================================================
# CloudFront Alarms
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  count = var.enable_cloudfront_alarms ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-cloudfront-5xx-errors"
  alarm_description   = "CloudFront 5xx error rate is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 1 # 1% error rate
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.incident_critical.arn]

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = var.tags
}

# ============================================================================
# CloudWatch Dashboard
# ============================================================================

resource "aws_cloudwatch_dashboard" "incident_response" {
  dashboard_name = "${var.project}-${var.environment}-incident-response"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "5XXError", { stat = "Sum", label = "API 5xx Errors" }],
            [".", "4XXError", { stat = "Sum", label = "API 4xx Errors" }],
            [".", "Latency", { stat = "Average", label = "API Latency" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "API Gateway Health"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", { stat = "Sum", label = "Total Errors" }],
            [".", "Throttles", { stat = "Sum", label = "Throttles" }],
            [".", "ConcurrentExecutions", { stat = "Maximum", label = "Concurrent Executions" }],
            [".", "Duration", { stat = "Average", label = "Average Duration" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Health"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = concat(
            [for table in var.dynamodb_table_names : ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", table]],
            [for table in var.dynamodb_table_names : ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", table]]
          )
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "DynamoDB Throttling"
        }
      }
    ]
  })
}

# ============================================================================
# CloudWatch Insights Queries
# ============================================================================

resource "aws_cloudwatch_query_definition" "lambda_errors" {
  name = "${var.project}-${var.environment}/lambda-errors"

  log_group_names = [
    "/aws/lambda/${var.project}-${var.environment}-read",
    "/aws/lambda/${var.project}-${var.environment}-write"
  ]

  query_string = <<-QUERY
    fields @timestamp, @message, @logStream
    | filter @message like /ERROR/
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "lambda_performance" {
  name = "${var.project}-${var.environment}/lambda-performance"

  log_group_names = [
    "/aws/lambda/${var.project}-${var.environment}-read",
    "/aws/lambda/${var.project}-${var.environment}-write"
  ]

  query_string = <<-QUERY
    filter @type = "REPORT"
    | stats avg(@duration), max(@duration), min(@duration), count(*) by bin(5m)
  QUERY
}
