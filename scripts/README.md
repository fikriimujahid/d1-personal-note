# Scripts Directory

This directory contains operational and incident response scripts for the d1-personal-note application.

## Available Scripts

### 🚨 Incident Response

#### `incident-response.ps1`
Automated incident detection, investigation, and recovery toolkit.

**Features**:
- Automated health checks across all AWS services
- Real-time log streaming and analysis
- CloudWatch alarm monitoring
- Automated rollback capabilities
- DynamoDB point-in-time restore
- CloudTrail event investigation

**Usage**:

```powershell
# Detect incidents (recommended first step)
.\incident-response.ps1 -Action detect

# Detect specific service issues
.\incident-response.ps1 -Action detect -Service lambda
.\incident-response.ps1 -Action detect -Service dynamodb
.\incident-response.ps1 -Action detect -Service api

# Investigate Lambda function
.\incident-response.ps1 -Action investigate `
  -FunctionName d1-personal-note-read-main `
  -LookbackHours 2

# Health check all services
.\incident-response.ps1 -Action health-check

# Rollback Lambda deployment
.\incident-response.ps1 -Action rollback -Service lambda `
  -FunctionName d1-personal-note-write-main

# Restore DynamoDB table
.\incident-response.ps1 -Action restore `
  -Service dynamodb `
  -TableName d1-personal-note-main-notes `
  -RestoreTime "2025-12-28T00:00:00Z"
```

**Parameters**:
- `-Action`: detect | investigate | rollback | restore | health-check
- `-Service`: lambda | api | dynamodb | cognito | cloudfront | all
- `-FunctionName`: Specific Lambda function name
- `-TableName`: DynamoDB table name
- `-RestoreTime`: ISO 8601 timestamp for restore
- `-Environment`: dev | staging | main (default: main)
- `-Region`: AWS region (default: ap-southeast-1)
- `-LookbackHours`: How far back to look for metrics (default: 1)

**Output**:
- Color-coded console output
- Alarm status
- Service health metrics
- Error logs
- CloudTrail events
- Recovery recommendations

---

## Prerequisites

### AWS CLI
Must be installed and configured:
```powershell
# Check installation
aws --version

# Configure credentials
aws configure --profile dev
aws configure --profile main
```

### PowerShell
- Windows PowerShell 5.1+ or PowerShell Core 7+
- Required modules: None (uses AWS CLI)

### Permissions
The AWS credentials must have permissions for:
- CloudWatch: `describe-alarms`, `get-metric-statistics`
- Lambda: `get-function`, `list-versions-by-function`, `update-function-configuration`
- DynamoDB: `describe-table`, `restore-table-to-point-in-time`
- CloudWatch Logs: `filter-log-events`, `tail`
- CloudTrail: `lookup-events`
- Cognito: `describe-user-pool`, `admin-user-global-sign-out`

---

## Quick Start Guide

### Initial Setup
```powershell
# 1. Navigate to scripts directory
cd c:\DEMOP\d1-personal-note\scripts

# 2. Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. Run health check to verify setup
.\incident-response.ps1 -Action health-check
```

### During an Incident

**Step 1: Detection**
```powershell
# Quick health check
.\incident-response.ps1 -Action detect
```

**Step 2: Investigation**
```powershell
# If Lambda errors detected
.\incident-response.ps1 -Action investigate `
  -FunctionName d1-personal-note-read-main

# Check CloudWatch Logs Insights
# Go to AWS Console -> CloudWatch -> Logs Insights
# Use saved query: "d1-personal-note-main/lambda-errors"
```

**Step 3: Recovery**
```powershell
# Rollback if needed
cd ..\api
sam deploy --parameter-overrides Environment=main

# Or use automated script
.\incident-response.ps1 -Action rollback -Service api
```

**Step 4: Verification**
```powershell
# Confirm resolution
.\incident-response.ps1 -Action health-check
```

---

## Troubleshooting

### Error: "AWS CLI not found"
```powershell
# Install AWS CLI
winget install Amazon.AWSCLI
# Or download from: https://aws.amazon.com/cli/
```

### Error: "Access Denied"
```powershell
# Check AWS credentials
aws sts get-caller-identity

# Configure correct profile
$env:AWS_PROFILE = "main"
```

### Error: "Parameter validation failed"
```powershell
# Check required parameters
Get-Help .\incident-response.ps1 -Detailed
```

---

## Integration with Monitoring

This script integrates with the monitoring infrastructure defined in:
- `infra/terraform/modules/monitoring/` - Terraform module creating alarms
- `docs/incident-response.md` - Full incident response plan
- `docs/incident-response-quick-ref.md` - Quick reference guide

### How It Works

1. **Monitoring module** creates CloudWatch alarms
2. **Alarms trigger** SNS notifications via email
3. **On-call engineer** receives alert
4. **Engineer runs** `incident-response.ps1 -Action detect`
5. **Script provides** real-time status and recommendations
6. **Engineer follows** automated recovery steps

---

## Best Practices

### Regular Testing
```powershell
# Run weekly health checks
.\incident-response.ps1 -Action health-check

# Practice incident response quarterly
# - Trigger test alarm
# - Run investigation
# - Practice rollback in dev environment
```

### Documentation
- Always document actions taken during incidents
- Update runbooks based on learnings
- Keep contact information current

### Automation
- Use this script for consistent incident handling
- Avoid manual AWS console changes when possible
- Log all recovery actions

---

## Adding New Scripts

When adding new operational scripts:

1. **Follow naming convention**: `action-purpose.ps1`
2. **Add help documentation**: Use PowerShell comment-based help
3. **Include error handling**: `$ErrorActionPreference = 'Stop'`
4. **Use color-coded output**: Success (Green), Warning (Yellow), Error (Red)
5. **Update this README**: Document the new script

---

## Related Documentation

- [Incident Response Plan](../docs/incident-response.md) - Full IR documentation
- [Quick Reference Guide](../docs/incident-response-quick-ref.md) - Printable cheat sheet
- [Monitoring Module](../infra/terraform/modules/monitoring/README.md) - CloudWatch setup
- [API Documentation](../api/README.md) - Lambda functions
- [Infrastructure](../infra/terraform/README.md) - Terraform configuration

---

## Support

For questions or issues with these scripts:
1. Check the troubleshooting section above
2. Review the related documentation
3. Contact the DevOps team
4. Create an issue in the repository

---

**Last Updated**: 2025-12-28  
**Maintained By**: DevOps Team
