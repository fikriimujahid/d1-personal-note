# Incident Response Plan

## Table of Contents
1. [Overview](#overview)
2. [Incident Response Team](#incident-response-team)
3. [Incident Severity Levels](#incident-severity-levels)
4. [Incident Response Phases](#incident-response-phases)
5. [Runbooks by Incident Type](#runbooks-by-incident-type)
6. [Monitoring & Detection](#monitoring--detection)
7. [Communication Plan](#communication-plan)
8. [Post-Incident Activities](#post-incident-activities)

---

## Overview

This document defines the **Incident Response Plan** for the d1-personal-note application, a serverless note-taking application deployed on AWS. The plan covers detection, response, containment, recovery, and post-incident activities.

### Scope
- **API Layer**: AWS Lambda functions (ReadNotesFunction, WriteNotesFunction)
- **Frontend**: Static website hosted on S3/CloudFront
- **Database**: DynamoDB tables
- **Authentication**: AWS Cognito User Pools
- **Infrastructure**: Terraform-managed AWS resources

### Objectives
1. **Minimize impact** of security incidents and service disruptions
2. **Restore normal operations** as quickly as possible
3. **Learn and improve** from each incident
4. **Maintain compliance** with security requirements

### Related Documents
- **[Disaster Recovery Plan](disaster-recovery.md)**: Backup scope, RPO/RTO, restore procedures
- **[Tabletop Exercise - Security Incident](tabletop-exercise-security-incident.md)**: Security incident simulation
- **[Tabletop Exercise - Stakeholder Report](tabletop-exercise-stakeholder-report.md)**: Stakeholder communication

---

## Incident Response Team

### Roles and Responsibilities

| Role | Responsibilities | Contact |
|------|-----------------|---------|
| **Incident Commander** | Leads response, makes decisions, coordinates team | Primary on-call |
| **Technical Lead** | Investigates root cause, implements fixes | DevOps/Backend Engineer |
| **Communications Lead** | Manages stakeholder communication | Project Manager |
| **Security Lead** | Handles security incidents, forensics | Security Engineer |

### On-Call Rotation
- Primary: Available 24/7 via phone/Slack
- Secondary: Backup if primary unavailable
- Escalation: Manager/Director level

---

## Incident Severity Levels

| Severity | Definition | Response Time | Examples |
|----------|-----------|---------------|----------|
| **P0 - Critical** | Complete service outage, data breach | Immediate (5 min) | API down, database compromised, authentication failure |
| **P1 - High** | Major feature broken, degraded performance | 15 minutes | High error rate (>5%), slow response times (>3s) |
| **P2 - Medium** | Minor feature broken, limited user impact | 1 hour | Single endpoint failing, UI bug affecting small user group |
| **P3 - Low** | Cosmetic issues, no user impact | Next business day | Minor UI glitch, non-critical warning in logs |

---

## Incident Response Phases

### 1. Detection & Triage (0-15 min)

**Objectives**: Identify and classify the incident

**Actions**:
1. **Alert received** via:
   - CloudWatch Alarm (email/SNS)
   - User reports
   - Monitoring dashboards
   - Security scan findings

2. **Initial assessment**:
   ```powershell
   # Check CloudWatch metrics
   aws cloudwatch get-metric-statistics `
     --namespace AWS/Lambda `
     --metric-name Errors `
     --dimensions Name=FunctionName,Value=d1-personal-note-write-main `
     --start-time (Get-Date).AddHours(-1).ToUniversalTime() `
     --end-time (Get-Date).ToUniversalTime() `
     --period 300 `
     --statistics Sum
   ```

3. **Severity assignment**: Use table above
4. **Incident ticket created**: Log in ticketing system with:
   - Timestamp
   - Severity
   - Affected components
   - Initial symptoms

### 2. Containment (15-30 min)

**Objectives**: Prevent further damage, isolate affected systems

**Actions by Incident Type**:

#### Security Breach
```powershell
# 1. Rotate all credentials immediately
aws cognito-idp admin-user-global-sign-out `
  --user-pool-id ap-southeast-1_XXXXXXXXX `
  --username suspicious-user@example.com

# 2. Disable compromised IAM credentials
aws iam update-access-key `
  --access-key-id $accessKey `
  --status Inactive

# 3. Enable CloudTrail logging if not already enabled
aws cloudtrail start-logging --name d1-personal-note-trail
```

#### API Outage
```powershell
# 1. Check Lambda function health
aws lambda get-function --function-name d1-personal-note-read-main

# 2. Check recent deployments
aws lambda list-versions-by-function --function-name d1-personal-note-read-main

# 3. Rollback if needed
sam deploy --parameter-overrides Environment=main --no-confirm-changeset
```

#### Database Issue
```powershell
# 1. Check DynamoDB table status
aws dynamodb describe-table --table-name d1-personal-note-main-notes

# 2. Check for throttling
aws cloudwatch get-metric-statistics `
  --namespace AWS/DynamoDB `
  --metric-name UserErrors `
  --dimensions Name=TableName,Value=d1-personal-note-main-notes `
  --start-time (Get-Date).AddHours(-1).ToUniversalTime() `
  --end-time (Get-Date).ToUniversalTime() `
  --period 300 `
  --statistics Sum

# 3. Enable point-in-time recovery if not enabled
aws dynamodb update-continuous-backups `
  --table-name d1-personal-note-main-notes `
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

### 3. Investigation (Parallel with Containment)

**Objectives**: Identify root cause

**Data Sources**:
1. **CloudWatch Logs**:
   ```powershell
   # Stream Lambda logs
   aws logs tail /aws/lambda/d1-personal-note-read-main --follow
   ```

2. **X-Ray Traces**:
   - Open AWS Console → X-Ray → Traces
   - Filter by error status codes
   - Analyze service map for bottlenecks

3. **CloudTrail**:
   ```powershell
   # Check recent API calls
   aws cloudtrail lookup-events `
     --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteTable `
     --start-time (Get-Date).AddDays(-1).ToUniversalTime()
   ```

4. **Application Logs**:
   - Check structured JSON logs in CloudWatch
   - Look for ERROR level messages
   - Correlate with X-Ray trace IDs

5. **WAF Logs** (if enabled):
   - Check for unusual traffic patterns
   - Identify blocked requests

### 4. Recovery (30 min - 2 hours)

**Objectives**: Restore normal service

**Standard Recovery Procedures**:

#### Lambda Recovery
```powershell
# Option 1: Rollback to previous version
cd api
sam deploy --parameter-overrides Environment=main

# Option 2: Update environment variable
aws lambda update-function-configuration `
  --function-name d1-personal-note-read-main `
  --environment Variables={TABLE_NAME=d1-personal-note-main-notes,LOG_LEVEL=INFO}

# Option 3: Increase memory/timeout
aws lambda update-function-configuration `
  --function-name d1-personal-note-read-main `
  --memory-size 256 `
  --timeout 30
```

#### Frontend Recovery
```powershell
# Rollback CloudFront distribution
cd frontend
npm run build
aws s3 sync dist/ s3://p1-serverless-web-app-main-hosting/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation `
  --distribution-id EXXXXXXXXXXXXX `
  --paths "/*"
```

#### DynamoDB Recovery
```powershell
# Restore from point-in-time
aws dynamodb restore-table-to-point-in-time `
  --source-table-name d1-personal-note-main-notes `
  --target-table-name d1-personal-note-main-notes-restored `
  --restore-date-time (Get-Date).AddHours(-2).ToUniversalTime()

# Switch application to restored table (update Terraform/SAM)
```

#### Infrastructure Recovery
```powershell
# Re-apply Terraform to restore infrastructure
cd infra/terraform
terraform init -backend-config=environments/main/backend.hcl
terraform plan -var-file=environments/main/terraform.tfvars
terraform apply -var-file=environments/main/terraform.tfvars -auto-approve
```

### 5. Verification (15-30 min)

**Objectives**: Confirm service is fully restored

**Checklist**:
- [ ] All CloudWatch alarms back to OK state
- [ ] API health check passing
- [ ] Frontend accessible
- [ ] Authentication working
- [ ] CRUD operations functioning
- [ ] Error rates normal (<1%)
- [ ] Response times normal (<500ms)
- [ ] No active security threats

**Verification Script**:
```powershell
# API health check
$apiUrl = "https://your-api-url.amazonaws.com/main"
Invoke-RestMethod -Uri "$apiUrl/notes" -Headers @{Authorization="Bearer $token"}

# Frontend check
$frontendUrl = "https://p1.fikri.dev"
$response = Invoke-WebRequest -Uri $frontendUrl
if ($response.StatusCode -eq 200) {
    Write-Host "Frontend is accessible" -ForegroundColor Green
}
```

---

## Runbooks by Incident Type

### 1. API High Error Rate

**Symptoms**:
- CloudWatch Alarm: ReadErrorsAlarm or WriteErrorsAlarm triggered
- Error rate > 5%

**Runbook**:

1. **Check CloudWatch Logs**:
   ```powershell
   aws logs filter-log-events `
     --log-group-name /aws/lambda/d1-personal-note-read-main `
     --filter-pattern "ERROR" `
     --start-time (Get-Date).AddHours(-1).ToUniversalTime().ToString("o")
   ```

2. **Common Causes**:
   - DynamoDB throttling → Increase capacity or enable auto-scaling
   - Lambda timeout → Increase timeout in template.yaml
   - Invalid input → Check request validation logic
   - External dependency failure → Check X-Ray for downstream errors

3. **Fix**:
   ```powershell
   # If DynamoDB throttling
   aws dynamodb update-table `
     --table-name d1-personal-note-main-notes `
     --billing-mode PAY_PER_REQUEST
   ```

4. **Verify**: Error rate drops below 1%

---

### 2. Authentication Failure

**Symptoms**:
- Users unable to log in
- 401 Unauthorized errors
- Cognito alarms triggered

**Runbook**:

1. **Check Cognito User Pool status**:
   ```powershell
   aws cognito-idp describe-user-pool `
     --user-pool-id ap-southeast-1_XXXXXXXXX
   ```

2. **Common Causes**:
   - Expired JWT tokens → Normal, users need to re-login
   - Cognito configuration error → Check user pool settings
   - API Gateway authorizer misconfigured → Check template.yaml

3. **Fix**:
   ```powershell
   # Force user to re-authenticate
   aws cognito-idp admin-user-global-sign-out `
     --user-pool-id ap-southeast-1_XXXXXXXXX `
     --username user@example.com
   ```

4. **Verify**: Users can successfully authenticate

---

### 3. Database Corruption/Data Loss

**Symptoms**:
- Missing or incorrect data
- DynamoDB table errors
- Data integrity complaints

**Runbook**:

1. **Assess scope**:
   ```powershell
   # Check recent writes
   aws dynamodb query `
     --table-name d1-personal-note-main-notes `
     --key-condition-expression "userId = :userId" `
     --expression-attribute-values '{":userId":{"S":"test-user"}}'
   ```

2. **Immediate action**: **STOP ALL WRITES**
   ```powershell
   # Disable write Lambda temporarily
   aws lambda update-function-configuration `
     --function-name d1-personal-note-write-main `
     --environment Variables={MAINTENANCE_MODE=true}
   ```

3. **Restore from backup**:
   ```powershell
   # Restore from point-in-time (last 35 days)
   aws dynamodb restore-table-to-point-in-time `
     --source-table-name d1-personal-note-main-notes `
     --target-table-name d1-personal-note-main-notes-restored `
     --restore-date-time 2025-12-28T00:00:00Z
   ```

4. **Verify data**: Compare restored table with known good state

5. **Switch traffic**: Update application to use restored table

---

### 4. Security Incident (Unauthorized Access)

**Symptoms**:
- Suspicious CloudTrail events
- Unauthorized API calls
- Data exfiltration detected
- Security scan findings (Critical/High)

**Runbook**:

1. **IMMEDIATE CONTAINMENT**:
   ```powershell
   # 1. Rotate ALL credentials
   aws iam update-access-key --access-key-id AKIAXXXXX --status Inactive
   
   # 2. Force sign-out all users
   aws cognito-idp admin-user-global-sign-out --user-pool-id POOL_ID --username USER
   
   # 3. Enable MFA if not already enabled
   aws cognito-idp set-user-pool-mfa-config `
     --user-pool-id POOL_ID `
     --mfa-configuration ENFORCED
   
   # 4. Block suspicious IPs via WAF (if enabled)
   aws wafv2 update-ip-set `
     --name blocked-ips `
     --scope CLOUDFRONT `
     --id IP_SET_ID `
     --addresses 192.0.2.1/32
   ```

2. **Forensics**:
   ```powershell
   # Check CloudTrail for unauthorized actions
   aws cloudtrail lookup-events `
     --lookup-attributes AttributeKey=Username,AttributeValue=suspicious-user `
     --max-items 100
   
   # Export CloudWatch logs for analysis
   aws logs create-export-task `
     --log-group-name /aws/lambda/d1-personal-note-write-main `
     --from (Get-Date).AddDays(-7).ToFileTimeUtc() `
     --to (Get-Date).ToFileTimeUtc() `
     --destination s3-bucket-for-forensics
   ```

3. **Assess damage**:
   - Check for unauthorized data access
   - Check for data modifications
   - Check for data exfiltration
   - Review IAM policy changes

4. **Remediation**:
   - Patch vulnerabilities
   - Update security groups
   - Review and update IAM policies
   - Enable additional security controls

5. **Notification**:
   - Notify affected users (if PII exposed)
   - Report to compliance team
   - File incident report

---

### 5. DDoS / Rate Limiting

**Symptoms**:
- Extremely high request rate
- API Gateway throttling errors
- Lambda concurrent execution maxed out
- High costs

**Runbook**:

1. **Check metrics**:
   ```powershell
   # API Gateway metrics
   aws cloudwatch get-metric-statistics `
     --namespace AWS/ApiGateway `
     --metric-name Count `
     --dimensions Name=ApiName,Value=d1-personal-note-api-main `
     --start-time (Get-Date).AddHours(-1).ToUniversalTime() `
     --end-time (Get-Date).ToUniversalTime() `
     --period 60 `
     --statistics Sum
   ```

2. **Immediate action**:
   ```powershell
   # Enable WAF rate limiting (if not already enabled)
   # This requires WAF to be configured in Terraform
   
   # Reduce Lambda concurrency temporarily
   aws lambda put-function-concurrency `
     --function-name d1-personal-note-write-main `
     --reserved-concurrent-executions 10
   ```

3. **Identify source**:
   - Check CloudWatch Logs for IP addresses
   - Review API Gateway access logs
   - Check WAF logs

4. **Block malicious traffic**:
   - Update WAF IP block list
   - Add rate limiting rules

---

### 6. Infrastructure Drift

**Symptoms**:
- Terraform plan shows unexpected changes
- Manual changes detected
- Resources don't match code

**Runbook**:

1. **Detect drift**:
   ```powershell
   cd infra/terraform
   terraform init -backend-config=environments/main/backend.hcl
   terraform plan -var-file=environments/main/terraform.tfvars
   ```

2. **Review changes**:
   - Check CloudTrail for who made manual changes
   - Assess impact of drift

3. **Remediation**:
   ```powershell
   # Option 1: Revert manual changes (import into Terraform)
   terraform import module.database.aws_dynamodb_table.notes d1-personal-note-main-notes
   
   # Option 2: Apply Terraform to restore desired state
   terraform apply -var-file=environments/main/terraform.tfvars -auto-approve
   ```

4. **Prevention**:
   - Enable AWS Config to detect drift
   - Restrict manual changes via IAM policies
   - Require all changes through CI/CD

---

## Monitoring & Detection

### CloudWatch Alarms (Already Implemented)

1. **Lambda Error Alarms**:
   - `ReadErrorsAlarm`: Triggers if ReadNotesFunction errors > 0
   - `WriteErrorsAlarm`: Triggers if WriteNotesFunction errors > 0
   - **Action**: Email notification

2. **Budget Alarms** (Implemented in Terraform):
   - 80% of monthly budget
   - 100% forecasted budget
   - **Action**: Email notification

### Recommended Additional Alarms

See `infra/terraform/modules/monitoring/` (to be created) for:
- API Gateway 5xx errors
- Lambda duration (timeout warnings)
- DynamoDB throttling events
- Cognito authentication failures
- CloudFront 5xx errors

---

## Communication Plan

### Internal Communication

**During Incident**:
- **Slack channel**: `#incident-response`
- **Status updates**: Every 30 minutes during P0/P1, hourly for P2
- **Escalation**: If unresolved after 2 hours (P0), 4 hours (P1)

### External Communication

**User Notification**:
- **P0 incidents**: Update status page immediately
- **P1 incidents**: Update status page within 30 min
- **P2/P3**: No user notification unless prolonged

**Template**:
```
Subject: [SERVICE STATUS] Brief Description

We are currently investigating [issue description]. 

Impact: [affected features]
Started: [timestamp]
Current Status: [investigating/identified/fixing/monitoring]

We will provide updates every [timeframe].

For questions, contact: support@example.com
```

---

## Post-Incident Activities

### Incident Review Meeting (Within 48 hours)

**Attendees**: Incident response team + stakeholders

**Agenda**:
1. Timeline of events
2. Root cause analysis (5 Whys)
3. What went well
4. What didn't go well
5. Action items

### Post-Incident Report Template

```markdown
# Incident Report: [Title]

**Date**: YYYY-MM-DD
**Severity**: P0/P1/P2/P3
**Duration**: X hours Y minutes
**Affected Users**: X users / X%

## Summary
Brief description of the incident.

## Timeline
- HH:MM - Event detected
- HH:MM - Incident declared
- HH:MM - Containment actions taken
- HH:MM - Root cause identified
- HH:MM - Fix deployed
- HH:MM - Incident resolved

## Root Cause
5 Whys analysis...

## Impact
- Users affected: X
- Downtime: X minutes
- Data loss: None/Partial/Complete

## Resolution
What fixed the issue.

## Action Items
1. [ACTION] - Owner - Due Date
2. [ACTION] - Owner - Due Date

## Lessons Learned
What we learned and will improve.
```

### Action Item Tracking

- Log all action items in project management tool
- Assign owners and due dates
- Review in next sprint planning
- Update runbooks based on learnings

---

## Appendix

### Emergency Contacts

| Name | Role | Phone | Email |
|------|------|-------|-------|
| [Name] | Incident Commander | +XX XXXX XXXX | name@example.com |
| [Name] | Technical Lead | +XX XXXX XXXX | name@example.com |
| [Name] | Security Lead | +XX XXXX XXXX | name@example.com |

### Key Resources

- **AWS Console**: https://console.aws.amazon.com
- **Status Page**: https://status.example.com
- **Monitoring Dashboard**: CloudWatch Dashboard
- **Documentation**: https://github.com/org/repo/docs

### Quick Reference Commands

```powershell
# Check API health
curl https://your-api-url.com/main/notes

# Stream Lambda logs
aws logs tail /aws/lambda/d1-personal-note-read-main --follow

# Check CloudWatch alarms
aws cloudwatch describe-alarms --state-value ALARM

# Rollback deployment
cd api && sam deploy --parameter-overrides Environment=main

# Check recent CloudTrail events
aws cloudtrail lookup-events --max-items 20
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-12-28  
**Next Review**: 2026-01-28  
**Owner**: DevOps Team
