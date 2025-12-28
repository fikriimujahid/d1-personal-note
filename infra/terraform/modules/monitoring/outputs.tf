# ============================================================================
# Terraform Module: Monitoring - Outputs
# ============================================================================

output "critical_incident_topic_arn" {
  description = "ARN of the SNS topic for critical incidents"
  value       = aws_sns_topic.incident_critical.arn
}

output "warning_incident_topic_arn" {
  description = "ARN of the SNS topic for warning-level incidents"
  value       = aws_sns_topic.incident_warning.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.incident_response.dashboard_name
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.incident_response.dashboard_name}"
}

output "composite_alarm_name" {
  description = "Name of the composite alarm for overall API health"
  value       = aws_cloudwatch_composite_alarm.api_health.alarm_name
}

output "alarm_names" {
  description = "List of all created alarm names"
  value = concat(
    [
      aws_cloudwatch_metric_alarm.api_5xx_errors.alarm_name,
      aws_cloudwatch_metric_alarm.api_4xx_errors.alarm_name,
      aws_cloudwatch_metric_alarm.api_latency.alarm_name,
      aws_cloudwatch_metric_alarm.lambda_errors_high.alarm_name,
      aws_cloudwatch_metric_alarm.lambda_duration.alarm_name,
      aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name,
      aws_cloudwatch_metric_alarm.lambda_concurrent_executions.alarm_name,
    ],
    aws_cloudwatch_metric_alarm.dynamodb_read_throttle[*].alarm_name,
    aws_cloudwatch_metric_alarm.dynamodb_write_throttle[*].alarm_name,
    aws_cloudwatch_metric_alarm.dynamodb_system_errors[*].alarm_name,
    aws_cloudwatch_metric_alarm.cognito_user_auth_errors[*].alarm_name,
    aws_cloudwatch_metric_alarm.cloudfront_5xx_errors[*].alarm_name
  )
}

output "log_group_name" {
  description = "CloudWatch log group for incident response"
  value       = aws_cloudwatch_log_group.incident_response.name
}

output "insights_query_ids" {
  description = "CloudWatch Insights saved query IDs"
  value = {
    lambda_errors      = aws_cloudwatch_query_definition.lambda_errors.query_definition_id
    lambda_performance = aws_cloudwatch_query_definition.lambda_performance.query_definition_id
  }
}
