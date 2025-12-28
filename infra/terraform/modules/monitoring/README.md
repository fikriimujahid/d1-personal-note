# Monitoring Module

This Terraform module creates comprehensive monitoring and alerting infrastructure for incident response.

## Features

- **SNS Topics**: Separate topics for critical (P0/P1) and warning (P2/P3) incidents
- **CloudWatch Alarms**: Automated detection of incidents across:
  - API Gateway (5xx/4xx errors, latency)
  - Lambda (errors, throttles, duration, concurrent executions)
  - DynamoDB (read/write throttling, system errors)
  - Cognito (authentication failures)
  - CloudFront (5xx errors)
- **Composite Alarms**: Combine multiple signals for better incident detection
- **CloudWatch Dashboard**: Visual overview of system health
- **CloudWatch Insights Queries**: Pre-configured queries for troubleshooting

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project     = "d1-personal-note"
  environment = "main"
  aws_region  = "ap-southeast-1"

  # Notification emails
  critical_notification_emails = ["oncall@example.com", "team-lead@example.com"]
  warning_notification_emails  = ["team@example.com"]

  # Service configuration
  api_name                   = "d1-personal-note-api-main"
  dynamodb_table_names       = ["d1-personal-note-main-notes"]
  cognito_user_pool_id       = "ap-southeast-1_XXXXXXXXX"
  cloudfront_distribution_id = "EXXXXXXXXXXXXX"

  # Optional: KMS encryption for CloudWatch Logs
  kms_key_arn = "arn:aws:kms:ap-southeast-1:XXXXXXXXXXXX:key/xxxxx"

  tags = {
    project     = "d1-personal-note"
    environment = "main"
    managed_by  = "terraform"
  }
}
```

## Alarm Thresholds

| Alarm | Threshold | Rationale |
|-------|-----------|-----------|
| API 5xx Errors | > 10 in 10 min | Server errors indicate system issues |
| API 4xx Errors | > 100 in 10 min | High rate suggests abuse or client issues |
| API Latency | > 3 seconds avg | User experience degradation |
| Lambda Errors | > 5 in 10 min | Function errors need investigation |
| Lambda Duration | > 8 seconds | 80% of timeout (10s) - Warning |
| Lambda Throttles | > 5 in 5 min | Hitting concurrency limits |
| DynamoDB Throttling | > 5 in 10 min | Capacity issues |
| Cognito Auth Errors | > 10 in 10 min | Authentication system issues |

## Outputs

- `critical_incident_topic_arn`: Use for P0/P1 incident alerts
- `warning_incident_topic_arn`: Use for P2/P3 incident alerts
- `dashboard_url`: Direct link to CloudWatch dashboard
- `alarm_names`: List of all created alarms

## Testing Alarms

```powershell
# Test SNS email subscription
aws sns publish `
  --topic-arn arn:aws:sns:ap-southeast-1:XXXXXXXXXXXX:d1-personal-note-main-incident-critical `
  --message "Test incident notification"

# Check alarm state
aws cloudwatch describe-alarms --alarm-names d1-personal-note-main-api-5xx-errors

# Set alarm state manually (for testing)
aws cloudwatch set-alarm-state `
  --alarm-name d1-personal-note-main-api-5xx-errors `
  --state-value ALARM `
  --state-reason "Testing incident response"
```

## CloudWatch Dashboard

Access the dashboard at:
```
https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1#dashboards:name=d1-personal-note-main-incident-response
```

The dashboard includes:
- API Gateway health metrics
- Lambda performance and error metrics
- DynamoDB throttling events

## CloudWatch Insights Queries

Pre-configured queries:
1. **lambda-errors**: Find all ERROR-level logs from Lambda functions
2. **lambda-performance**: Analyze Lambda execution duration trends

Access via CloudWatch → Logs → Insights → Saved queries

## Integration with Incident Response

This module supports the incident response plan documented in `docs/incident-response.md`:

1. **Detection**: CloudWatch alarms automatically detect incidents
2. **Notification**: SNS sends emails to on-call team
3. **Triage**: Dashboard provides quick health overview
4. **Investigation**: Insights queries help find root cause
5. **Resolution**: Alarms automatically clear when issue resolved

## Cost Considerations

- SNS: $0.50 per 1 million notifications + $2/month per email subscription
- CloudWatch Alarms: $0.10 per alarm per month
- CloudWatch Dashboard: $3 per dashboard per month
- CloudWatch Logs: $0.50 per GB ingested

Estimated monthly cost: ~$5-10 for typical usage

## Related Documentation

- [Incident Response Plan](../../../docs/incident-response.md)
- [Monitoring & Cost Control](../../../docs/monitoring.md)
