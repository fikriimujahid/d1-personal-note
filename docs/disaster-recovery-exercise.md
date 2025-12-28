# Disaster Recovery Exercise Guide

## Table of Contents
1. [Overview](#overview)
2. [Exercise Types](#exercise-types)
3. [Pre-Exercise Checklist](#pre-exercise-checklist)
4. [Exercise 1: DynamoDB Point-in-Time Recovery](#exercise-1-dynamodb-point-in-time-recovery)
5. [Exercise 2: Lambda Function Rollback](#exercise-2-lambda-function-rollback)
6. [Exercise 3: Frontend Recovery from Git](#exercise-3-frontend-recovery-from-git)
7. [Exercise 4: Full Infrastructure Rebuild](#exercise-4-full-infrastructure-rebuild)
8. [Exercise 5: Cognito User Pool Recovery](#exercise-5-cognito-user-pool-recovery)
9. [Exercise 6: Terraform State Recovery](#exercise-6-terraform-state-recovery)
10. [Post-Exercise Review](#post-exercise-review)
11. [Exercise Schedule](#exercise-schedule)

---

## Overview

### Purpose

This document provides structured disaster recovery exercises for the d1-personal-note application. These exercises validate our ability to recover from various failure scenarios and ensure our documented procedures are accurate and effective.

### Goals

1. **Validate Recovery Procedures**: Ensure documented steps work as expected
2. **Measure Recovery Times**: Compare actual RTO against targets
3. **Identify Gaps**: Discover missing documentation or tooling
4. **Train Team Members**: Build muscle memory for incident response
5. **Improve Confidence**: Reduce stress during actual incidents

### Scope

| Component             | Exercise Coverage | Priority |
|-----------------------|-------------------|----------|
| DynamoDB (Notes)      | Full restore test | High     |
| Lambda Functions      | Rollback test     | High     |
| Frontend (S3)         | Rebuild test      | Medium   |
| Cognito User Pool     | Export/Import     | Medium   |
| Terraform State       | Recovery test     | High     |
| Full Infrastructure   | Complete rebuild  | Annual   |

### Safety Guidelines

- NEVER run exercises on production during business hours without approval
- ALWAYS create test resources with distinct names (suffix: `-dr-test`)
- ALWAYS clean up test resources after exercises
- DOCUMENT all actions taken during exercises
- NOTIFY stakeholders before starting exercises

---

## Exercise Types

### Type A: Tabletop Exercise (No Execution)
- Walk through procedures verbally
- Identify gaps in documentation
- Duration: 1-2 hours
- Frequency: Monthly

### Type B: Partial Recovery Test
- Execute specific recovery procedures
- Create test resources (not affecting production)
- Duration: 2-4 hours
- Frequency: Quarterly

### Type C: Full Recovery Test
- Complete end-to-end recovery simulation
- May involve temporary service degradation
- Duration: 4-8 hours
- Frequency: Annually

### Type D: Chaos Engineering
- Inject controlled failures
- Test monitoring and alerting
- Duration: 1-2 hours
- Frequency: Quarterly (after maturity)

---

## Pre-Exercise Checklist

### 1 Week Before Exercise

| Task | Owner | Status |
|------|-------|--------|
| Schedule exercise window | DR Coordinator | [ ] |
| Notify all stakeholders | Communications | [ ] |
| Review and update runbooks | Technical Lead | [ ] |
| Verify AWS credentials are current | DevOps | [ ] |
| Confirm backup systems are operational | DevOps | [ ] |
| Prepare test data if needed | QA | [ ] |

### Day Before Exercise

| Task | Owner | Status |
|------|-------|--------|
| Send reminder to participants | DR Coordinator | [ ] |
| Verify all tools are accessible | DevOps | [ ] |
| Create exercise log document | DR Coordinator | [ ] |
| Confirm rollback plan is ready | Technical Lead | [ ] |
| Check current system health | DevOps | [ ] |

### Exercise Day (Before Start)

| Task | Owner | Status |
|------|-------|--------|
| Gather all participants | DR Coordinator | [ ] |
| Brief team on exercise scope | DR Coordinator | [ ] |
| Start recording/logging | Scribe | [ ] |
| Verify communication channels | All | [ ] |
| Take baseline measurements | DevOps | [ ] |

---

## Exercise 1: DynamoDB Point-in-Time Recovery

### Metadata

| Attribute | Value |
|-----------|-------|
| Exercise Type | B - Partial Recovery |
| Duration | 1-2 hours |
| Frequency | Quarterly |
| Target RTO | 1 hour |
| Target RPO | 5 minutes |
| Prerequisites | PITR enabled on table |

### Objectives

1. Validate PITR restore procedure
2. Measure actual restore time
3. Verify data integrity after restore
4. Document any issues encountered

### Scenario

> A developer accidentally deleted critical user notes due to a bug in the write handler. We need to restore the data to a point before the deletion occurred.

### Prerequisites Check

```powershell
# Step P1: Verify PITR is enabled
aws dynamodb describe-continuous-backups `
  --table-name d1-personal-note-main-notes `
  --region ap-southeast-1

# Expected: PointInTimeRecoveryStatus = "ENABLED"
# If DISABLED, enable it first:
# aws dynamodb update-continuous-backups `
#   --table-name d1-personal-note-main-notes `
#   --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

### Exercise Steps

#### Step 1: Document Current State (5 min)

```powershell
# 1.1: Record current item count
$baselineCount = aws dynamodb scan `
  --table-name d1-personal-note-main-notes `
  --select COUNT `
  --output json | ConvertFrom-Json

Write-Host "Baseline item count: $($baselineCount.Count)"
$exerciseStart = Get-Date
Write-Host "Exercise started: $exerciseStart"
```

**Record in exercise log:**
- Baseline item count: _______________
- Exercise start time: _______________

#### Step 2: Identify Restore Point (5 min)

```powershell
# 2.1: Get available restore window
$backupInfo = aws dynamodb describe-continuous-backups `
  --table-name d1-personal-note-main-notes `
  --region ap-southeast-1 `
  --output json | ConvertFrom-Json

$pitrInfo = $backupInfo.ContinuousBackupsDescription.PointInTimeRecoveryDescription

Write-Host "Earliest restore point: $($pitrInfo.EarliestRestorableDateTime)"
Write-Host "Latest restore point: $($pitrInfo.LatestRestorableDateTime)"
```

**Record in exercise log:**
- Earliest restore point: _______________
- Latest restore point: _______________
- Selected restore point: _______________

#### Step 3: Execute PITR Restore (15-30 min)

```powershell
# 3.1: Set restore parameters
$sourceTable = "d1-personal-note-main-notes"
$targetTable = "d1-personal-note-main-notes-dr-test-$(Get-Date -Format 'yyyyMMdd-HHmm')"
$restoreTime = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Source table: $sourceTable"
Write-Host "Target table: $targetTable"
Write-Host "Restore time: $restoreTime"

# 3.2: Execute restore
$restoreStart = Get-Date
aws dynamodb restore-table-to-point-in-time `
  --source-table-name $sourceTable `
  --target-table-name $targetTable `
  --restore-date-time $restoreTime `
  --region ap-southeast-1

# 3.3: Wait for restore to complete
Write-Host "Waiting for restore to complete..."
aws dynamodb wait table-exists --table-name $targetTable --region ap-southeast-1

# 3.4: Verify table is active
do {
    $status = (aws dynamodb describe-table --table-name $targetTable --output json | ConvertFrom-Json).Table.TableStatus
    Write-Host "Table status: $status"
    Start-Sleep -Seconds 10
} while ($status -ne "ACTIVE")

$restoreEnd = Get-Date
$restoreDuration = ($restoreEnd - $restoreStart).TotalMinutes
Write-Host "Restore completed in $restoreDuration minutes"
```

**Record in exercise log:**
- Restore start time: _______________
- Restore end time: _______________
- Duration: _______________ minutes
- Final table status: _______________

#### Step 4: Verify Data Integrity (10 min)

```powershell
# 4.1: Compare item counts
$restoredCount = aws dynamodb scan `
  --table-name $targetTable `
  --select COUNT `
  --output json | ConvertFrom-Json

Write-Host "Original table count: $($baselineCount.Count)"
Write-Host "Restored table count: $($restoredCount.Count)"

if ($baselineCount.Count -eq $restoredCount.Count) {
    Write-Host "SUCCESS: Item counts match" -ForegroundColor Green
} else {
    Write-Host "WARNING: Item counts differ" -ForegroundColor Yellow
}

# 4.2: Sample data verification (optional)
# Query a few known items and verify their content
aws dynamodb scan `
  --table-name $targetTable `
  --max-items 3 `
  --output table
```

**Record in exercise log:**
- Original count: _______________
- Restored count: _______________
- Counts match: [ ] Yes [ ] No
- Sample data verified: [ ] Yes [ ] No

#### Step 5: Simulate Application Switchover (5 min)

```powershell
# 5.1: Document what would be required for production switchover
Write-Host @"
Production Switchover Steps:
1. Update Lambda environment variable TABLE_NAME to: $targetTable
2. Deploy Lambda configuration change
3. Verify API Gateway is routing correctly
4. Monitor for errors in CloudWatch
"@

# Note: In a real scenario, you would execute these steps
# This exercise only documents the process
```

#### Step 6: Cleanup Test Resources (5 min)

```powershell
# 6.1: Delete test table
Write-Host "Cleaning up test table: $targetTable"
aws dynamodb delete-table --table-name $targetTable --region ap-southeast-1

# 6.2: Verify deletion
aws dynamodb wait table-not-exists --table-name $targetTable --region ap-southeast-1
Write-Host "Test table deleted successfully"
```

### Success Criteria

| Criteria | Target | Actual | Pass/Fail |
|----------|--------|--------|-----------|
| Restore completed | Yes | | |
| Restore time | < 60 min | | |
| Table status ACTIVE | Yes | | |
| Item count matches | Yes | | |
| Data integrity verified | Yes | | |
| Cleanup completed | Yes | | |

### Exercise Results

```
Exercise ID: DR-EX-DDB-PITR-[DATE]
Date: _______________
Participants: _______________
Duration: _______________ minutes
RTO Target: 60 minutes
RTO Actual: _______________ minutes
RPO Achieved: _______________ minutes
Overall Result: [ ] PASS [ ] FAIL
```

---

## Exercise 2: Lambda Function Rollback

### Metadata

| Attribute | Value |
|-----------|-------|
| Exercise Type | B - Partial Recovery |
| Duration | 30-60 minutes |
| Frequency | Monthly |
| Target RTO | 15 minutes |
| Prerequisites | Previous deployment exists |

### Objectives

1. Validate Lambda rollback procedure
2. Practice rapid deployment recovery
3. Verify SAM deployment process

### Scenario

> A recent deployment introduced a critical bug causing 500 errors. We need to rollback to the previous working version.

### Exercise Steps

#### Step 1: Document Current State (5 min)

```powershell
# 1.1: Get current function versions
$readFunction = "d1-personal-note-read-main"
$writeFunction = "d1-personal-note-write-main"

Write-Host "Current Read Function:"
aws lambda get-function --function-name $readFunction --query 'Configuration.[Version,LastModified,CodeSha256]' --output table

Write-Host "Current Write Function:"
aws lambda get-function --function-name $writeFunction --query 'Configuration.[Version,LastModified,CodeSha256]' --output table

# 1.2: List available versions
Write-Host "Available versions for Read Function:"
aws lambda list-versions-by-function --function-name $readFunction --output table

$exerciseStart = Get-Date
```

**Record in exercise log:**
- Current read function version: _______________
- Current write function version: _______________
- Available versions: _______________

#### Step 2: Simulate Rollback via SAM Redeploy (10-15 min)

```powershell
# 2.1: Navigate to API directory
cd c:\DEMOP\d1-personal-note\api

# 2.2: Verify build is current
npm run build

# 2.3: Deploy (this redeploys current code, simulating rollback)
$deployStart = Get-Date
sam deploy `
  --stack-name d1-personal-note-api-main `
  --parameter-overrides `
    Environment=main `
    DynamoDBTableName=d1-personal-note-main-notes `
    Project=d1-personal-note `
  --no-confirm-changeset `
  --no-fail-on-empty-changeset

$deployEnd = Get-Date
$deployDuration = ($deployEnd - $deployStart).TotalMinutes
Write-Host "Deployment completed in $deployDuration minutes"
```

**Record in exercise log:**
- Deploy start time: _______________
- Deploy end time: _______________
- Duration: _______________ minutes

#### Step 3: Verify Deployment (5 min)

```powershell
# 3.1: Check function was updated
Write-Host "Updated Read Function:"
aws lambda get-function --function-name $readFunction --query 'Configuration.[Version,LastModified]' --output table

# 3.2: Test function invocation (optional, requires auth)
# aws lambda invoke `
#   --function-name $readFunction `
#   --payload '{"httpMethod":"GET","path":"/notes"}' `
#   response.json

# 3.3: Check CloudWatch for errors
Write-Host "Checking recent logs for errors..."
aws logs filter-log-events `
  --log-group-name "/aws/lambda/$readFunction" `
  --filter-pattern "ERROR" `
  --start-time ((Get-Date).AddMinutes(-5).ToFileTimeUtc() / 10000 - 11644473600000) `
  --limit 5
```

### Success Criteria

| Criteria | Target | Actual | Pass/Fail |
|----------|--------|--------|-----------|
| Deployment completed | Yes | | |
| Deployment time | < 15 min | | |
| Functions updated | Yes | | |
| No errors in logs | Yes | | |

---

## Exercise 3: Frontend Recovery from Git

### Metadata

| Attribute | Value |
|-----------|-------|
| Exercise Type | B - Partial Recovery |
| Duration | 30-45 minutes |
| Frequency | Monthly |
| Target RTO | 30 minutes |
| Prerequisites | Git repository accessible |

### Objectives

1. Validate frontend rebuild process
2. Practice S3 deployment
3. Verify CloudFront invalidation

### Scenario

> The S3 bucket contents were accidentally deleted or corrupted. We need to rebuild and redeploy the frontend from source.

### Exercise Steps

#### Step 1: Verify Source Availability (5 min)

```powershell
# 1.1: Verify Git repository is accessible
cd c:\DEMOP\d1-personal-note
git status
git log -1 --oneline

# 1.2: Verify frontend source exists
ls frontend/src -Recurse | Measure-Object
```

#### Step 2: Rebuild Frontend (10 min)

```powershell
# 2.1: Navigate to frontend directory
cd c:\DEMOP\d1-personal-note\frontend

# 2.2: Install dependencies
$buildStart = Get-Date
npm ci

# 2.3: Build production bundle
npm run build

$buildEnd = Get-Date
$buildDuration = ($buildEnd - $buildStart).TotalMinutes
Write-Host "Build completed in $buildDuration minutes"

# 2.4: Verify build output
ls dist -Recurse | Measure-Object
```

**Record in exercise log:**
- Build start time: _______________
- Build end time: _______________
- Build duration: _______________ minutes
- Build output files: _______________ files

#### Step 3: Deploy to S3 (5 min)

```powershell
# 3.1: Get bucket name from Terraform output
$bucketName = "d1-personal-note-main-website"  # Update if different

# 3.2: Sync files to S3
$deployStart = Get-Date
aws s3 sync dist/ "s3://$bucketName/" --delete

$deployEnd = Get-Date
Write-Host "S3 sync completed in $(($deployEnd - $deployStart).TotalSeconds) seconds"
```

#### Step 4: Invalidate CloudFront Cache (5 min)

```powershell
# 4.1: Get CloudFront distribution ID
$distributions = aws cloudfront list-distributions --output json | ConvertFrom-Json
$distId = ($distributions.DistributionList.Items | 
    Where-Object { $_.Comment -like "*$bucketName*" } | 
    Select-Object -First 1).Id

Write-Host "CloudFront Distribution ID: $distId"

# 4.2: Create invalidation
$invalidation = aws cloudfront create-invalidation `
  --distribution-id $distId `
  --paths "/*" `
  --output json | ConvertFrom-Json

Write-Host "Invalidation ID: $($invalidation.Invalidation.Id)"
Write-Host "Status: $($invalidation.Invalidation.Status)"

# 4.3: Wait for invalidation to complete (optional)
# aws cloudfront wait invalidation-completed `
#   --distribution-id $distId `
#   --id $invalidation.Invalidation.Id
```

#### Step 5: Verify Frontend is Accessible (5 min)

```powershell
# 5.1: Test frontend URL
$frontendUrl = "https://d1.fikri.dev"  # Update with your domain
$response = Invoke-WebRequest -Uri $frontendUrl -UseBasicParsing

Write-Host "Status Code: $($response.StatusCode)"
Write-Host "Content Length: $($response.Content.Length) bytes"

if ($response.StatusCode -eq 200) {
    Write-Host "SUCCESS: Frontend is accessible" -ForegroundColor Green
} else {
    Write-Host "WARNING: Unexpected status code" -ForegroundColor Yellow
}
```

### Success Criteria

| Criteria | Target | Actual | Pass/Fail |
|----------|--------|--------|-----------|
| Build completed | Yes | | |
| S3 sync completed | Yes | | |
| CloudFront invalidated | Yes | | |
| Frontend accessible | Yes | | |
| Total time | < 30 min | | |

---

## Exercise 4: Full Infrastructure Rebuild

### Metadata

| Attribute | Value |
|-----------|-------|
| Exercise Type | C - Full Recovery |
| Duration | 4-8 hours |
| Frequency | Annually |
| Target RTO | 2 hours |
| Prerequisites | Terraform state accessible, Git repo accessible |

### Objectives

1. Validate complete infrastructure recreation
2. Test Terraform state recovery if needed
3. Verify all integrations work after rebuild

### Scenario

> A catastrophic failure has destroyed all infrastructure. We need to rebuild everything from scratch using our Infrastructure as Code.

### Warning

This exercise should only be performed:
- In a non-production environment, OR
- During a scheduled maintenance window, OR
- Using a separate AWS account for testing

### Exercise Steps

#### Phase 1: Preparation (30 min)

```powershell
# 1.1: Verify Terraform state is accessible
cd c:\DEMOP\d1-personal-note\infra\terraform
terraform init -backend-config=environments/main/backend.hcl

# 1.2: List current state
terraform state list

# 1.3: Create backup of current state
aws s3 cp s3://[STATE-BUCKET]/terraform.tfstate terraform.tfstate.backup
```

#### Phase 2: Terraform Apply (30-60 min)

```powershell
# 2.1: Plan infrastructure
terraform plan -var-file=environments/main/terraform.tfvars -out=rebuild.plan

# 2.2: Review plan carefully
# Ensure no unexpected destroys

# 2.3: Apply infrastructure
terraform apply rebuild.plan
```

#### Phase 3: Deploy API (15-30 min)

```powershell
# 3.1: Navigate to API directory
cd c:\DEMOP\d1-personal-note\api

# 3.2: Build and deploy
npm ci
npm run build
sam deploy --parameter-overrides Environment=main
```

#### Phase 4: Deploy Frontend (15-30 min)

```powershell
# 4.1: Navigate to frontend directory
cd c:\DEMOP\d1-personal-note\frontend

# 4.2: Build and deploy
npm ci
npm run build
aws s3 sync dist/ s3://[BUCKET-NAME]/ --delete

# 4.3: Invalidate CloudFront
aws cloudfront create-invalidation --distribution-id [DIST-ID] --paths "/*"
```

#### Phase 5: Verification (30 min)

```powershell
# 5.1: Verify all CloudWatch alarms are OK
aws cloudwatch describe-alarms --state-value ALARM

# 5.2: Test API endpoint
# (Requires authentication token)

# 5.3: Test frontend access
Invoke-WebRequest -Uri "https://[YOUR-DOMAIN]" -UseBasicParsing

# 5.4: Verify DNS resolution
nslookup [YOUR-DOMAIN]
```

### Success Criteria

| Criteria | Target | Actual | Pass/Fail |
|----------|--------|--------|-----------|
| Terraform apply successful | Yes | | |
| API deployed | Yes | | |
| Frontend deployed | Yes | | |
| DNS resolving | Yes | | |
| Authentication working | Yes | | |
| CRUD operations working | Yes | | |
| Total time | < 2 hours | | |

---

## Exercise 5: Cognito User Pool Recovery

### Metadata

| Attribute | Value |
|-----------|-------|
| Exercise Type | B - Partial Recovery |
| Duration | 2-3 hours |
| Frequency | Semi-annually |
| Target RTO | 4 hours |
| Prerequisites | User export exists |

### Objectives

1. Validate user export process
2. Test user import to new pool
3. Understand password reset requirements

### Important Notes

- User passwords CANNOT be exported or imported
- After recovery, all users must reset passwords
- This exercise creates a TEST user pool (not production)

### Exercise Steps

#### Step 1: Export Users from Current Pool (15 min)

```powershell
# 1.1: Get User Pool ID
$userPoolId = "ap-southeast-1_XXXXXXXXX"  # Replace with actual ID

# 1.2: Export users
$users = aws cognito-idp list-users `
  --user-pool-id $userPoolId `
  --output json | ConvertFrom-Json

Write-Host "Found $($users.Users.Count) users"

# 1.3: Save to file
$exportFile = "cognito-export-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
$users | ConvertTo-Json -Depth 10 | Out-File $exportFile

Write-Host "Exported to $exportFile"
```

#### Step 2: Create Test User Pool (30 min)

```powershell
# 2.1: Create test user pool using Terraform
# Create a temporary test configuration
# Note: This is a documentation exercise - actual creation would use Terraform

Write-Host @"
To create a test user pool:
1. Create a copy of auth module with test naming
2. Apply with: terraform apply -target=module.auth_test
3. Or use AWS Console for quick testing
"@
```

#### Step 3: Import Users (Simulated) (30 min)

```powershell
# 3.1: Document import process
Write-Host @"
User Import Process:
1. For each user in export file:
   a. Call admin-create-user
   b. Set user attributes
   c. Send password reset email

2. Users will receive password reset emails
3. Users must set new passwords before accessing app
"@

# 3.2: Example single user import (for testing)
# aws cognito-idp admin-create-user `
#   --user-pool-id [NEW-POOL-ID] `
#   --username test@example.com `
#   --user-attributes Name=email,Value=test@example.com
```

### Success Criteria

| Criteria | Target | Actual | Pass/Fail |
|----------|--------|--------|-----------|
| Export completed | Yes | | |
| User count correct | Yes | | |
| Import process documented | Yes | | |
| Password reset flow understood | Yes | | |

---

## Exercise 6: Terraform State Recovery

### Metadata

| Attribute | Value |
|-----------|-------|
| Exercise Type | B - Partial Recovery |
| Duration | 1-2 hours |
| Frequency | Semi-annually |
| Target RTO | 1 hour |
| Prerequisites | S3 versioning enabled on state bucket |

### Objectives

1. Validate state file recovery from S3 versions
2. Practice resource import if needed
3. Verify state integrity after recovery

### Scenario

> The Terraform state file has been corrupted. We need to recover from a previous version stored in S3.

### Exercise Steps

#### Step 1: Check Current State Health (5 min)

```powershell
# 1.1: Initialize and verify state
cd c:\DEMOP\d1-personal-note\infra\terraform
terraform init -backend-config=environments/main/backend.hcl

# 1.2: List state contents
terraform state list

# 1.3: Check for drift
terraform plan -var-file=environments/main/terraform.tfvars
```

#### Step 2: List Available State Versions (5 min)

```powershell
# 2.1: Get state bucket name from backend config
$backendFile = Get-Content environments/main/backend.hcl -Raw
if ($backendFile -match 'bucket\s*=\s*"([^"]+)"') {
    $stateBucket = $Matches[1]
    Write-Host "State bucket: $stateBucket"
}

# 2.2: List state file versions
$versions = aws s3api list-object-versions `
  --bucket $stateBucket `
  --prefix terraform.tfstate `
  --output json | ConvertFrom-Json

Write-Host "Available versions:"
$versions.Versions | ForEach-Object {
    Write-Host "  $($_.VersionId) - $($_.LastModified) - $($_.Size) bytes"
}
```

**Record in exercise log:**
- State bucket: _______________
- Number of versions available: _______________
- Latest version ID: _______________

#### Step 3: Download Previous Version (5 min)

```powershell
# 3.1: Select a version to recover (second most recent for testing)
$previousVersion = $versions.Versions[1].VersionId

# 3.2: Download to local file
aws s3api get-object `
  --bucket $stateBucket `
  --key terraform.tfstate `
  --version-id $previousVersion `
  state-recovery-test.tfstate

Write-Host "Downloaded version $previousVersion"
ls state-recovery-test.tfstate
```

#### Step 4: Verify Recovered State (10 min)

```powershell
# 4.1: Examine recovered state
$recoveredState = Get-Content state-recovery-test.tfstate | ConvertFrom-Json
Write-Host "State version: $($recoveredState.version)"
Write-Host "Terraform version: $($recoveredState.terraform_version)"
Write-Host "Resources: $($recoveredState.resources.Count)"

# 4.2: List resources in recovered state
$recoveredState.resources | ForEach-Object {
    Write-Host "  $($_.type).$($_.name)"
}
```

#### Step 5: Simulate State Restoration (Documentation Only)

```powershell
Write-Host @"
State Restoration Process (PRODUCTION):

1. BACKUP current state:
   aws s3 cp s3://$stateBucket/terraform.tfstate ./terraform.tfstate.corrupted

2. RESTORE previous version:
   aws s3 cp s3://$stateBucket/terraform.tfstate `
     --version-id $previousVersion `
     s3://$stateBucket/terraform.tfstate

3. VERIFY restoration:
   terraform init -reconfigure
   terraform state list
   terraform plan

4. IMPORT any missing resources if needed:
   terraform import [resource_address] [resource_id]
"@
```

#### Step 6: Cleanup (5 min)

```powershell
# 6.1: Remove test files
Remove-Item state-recovery-test.tfstate -ErrorAction SilentlyContinue
Write-Host "Cleanup completed"
```

### Success Criteria

| Criteria | Target | Actual | Pass/Fail |
|----------|--------|--------|-----------|
| Versions listed | Yes | | |
| Download successful | Yes | | |
| State integrity verified | Yes | | |
| Restoration process documented | Yes | | |

---

## Post-Exercise Review

### Immediate Actions (Within 1 hour)

1. **Document Findings**
   - Record all issues encountered
   - Note any deviations from documented procedures
   - Capture actual times vs. targets

2. **Update Documentation**
   - Fix any incorrect commands
   - Add missing steps
   - Clarify confusing instructions

3. **File Action Items**
   - Create tickets for gaps discovered
   - Assign owners and due dates

### Review Meeting (Within 1 week)

**Agenda:**
1. Exercise summary (10 min)
2. Review of findings (20 min)
3. Discussion of gaps (20 min)
4. Action item assignment (10 min)

**Discussion Questions:**
- Did the documented procedures work as expected?
- Were there any surprises or unexpected issues?
- Did we meet our RTO/RPO targets?
- What would make the next exercise more effective?
- Are there additional scenarios we should test?

### Exercise Report Template

```markdown
# DR Exercise Report

## Exercise Details
- Exercise ID: DR-EX-[TYPE]-[DATE]
- Date: YYYY-MM-DD
- Duration: X hours
- Participants: [Names]
- Exercise Type: [A/B/C/D]

## Summary
[Brief description of what was tested]

## Results

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| RTO    |        |        |        |
| RPO    |        |        |        |
| Success Criteria Met | X/Y |  |  |

## Issues Discovered
1. [Issue description]
   - Impact: [High/Medium/Low]
   - Remediation: [Action needed]

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
|        |       |          |        |

## Recommendations
- [Recommendation 1]
- [Recommendation 2]

## Attachments
- Exercise log
- Screenshots
- Command outputs
```

---

## Exercise Schedule

### Annual Schedule Template

| Month | Exercise | Type | Duration | Owner |
|-------|----------|------|----------|-------|
| January | DynamoDB PITR Recovery | B | 2 hrs | DevOps |
| February | Lambda Rollback | B | 1 hr | Backend Lead |
| March | Frontend Recovery | B | 1 hr | Frontend Lead |
| April | Tabletop Review | A | 2 hrs | DR Coordinator |
| May | DynamoDB PITR Recovery | B | 2 hrs | DevOps |
| June | Terraform State Recovery | B | 2 hrs | DevOps |
| July | Cognito User Export | B | 2 hrs | DevOps |
| August | Lambda Rollback | B | 1 hr | Backend Lead |
| September | Frontend Recovery | B | 1 hr | Frontend Lead |
| October | Tabletop Review | A | 2 hrs | DR Coordinator |
| November | DynamoDB PITR Recovery | B | 2 hrs | DevOps |
| December | Full Infrastructure Rebuild | C | 8 hrs | DevOps |

### Exercise Tracking

| Exercise ID | Date | Type | Result | RTO Met | Issues | Actions |
|-------------|------|------|--------|---------|--------|---------|
| | | | | | | |
| | | | | | | |
| | | | | | | |

---

**Document Version**: 1.0  
**Created**: 2025-12-28  
**Last Updated**: 2025-12-28  
**Next Review**: 2026-03-28  
**Owner**: DevOps Team  
**Status**: Active

---

### Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-28 | DevOps Team | Initial version |
