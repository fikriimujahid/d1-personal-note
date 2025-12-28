# Disaster Recovery Plan

## Table of Contents
1. [Overview](#overview)
2. [Recovery Objectives](#recovery-objectives)
3. [Backup Scope & Strategy](#backup-scope--strategy)
4. [Restore Procedures](#restore-procedures)
5. [Disaster Scenarios & Runbooks](#disaster-scenarios--runbooks)
6. [Testing & Validation](#testing--validation)
7. [Roles & Responsibilities](#roles--responsibilities)
8. [Appendix](#appendix)

---

## Overview

This document defines the **Disaster Recovery (DR) Plan** for the d1-personal-note application, a serverless note-taking application deployed on AWS. The plan covers backup strategies, recovery procedures, and recovery objectives for all critical components.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           d1-personal-note Architecture                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                 │
│  │   Route53    │────▶│  CloudFront  │────▶│    S3        │                 │
│  │  (DNS)       │     │  (CDN+WAF)   │     │  (Frontend)  │                 │
│  └──────────────┘     └──────────────┘     └──────────────┘                 │
│                              │                                               │
│                              ▼                                               │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                 │
│  │   Cognito    │◀───▶│ API Gateway  │────▶│   Lambda     │                 │
│  │ (User Pool)  │     │  (REST API)  │     │ (Read/Write) │                 │
│  └──────────────┘     └──────────────┘     └──────────────┘                 │
│                                                   │                          │
│                                                   ▼                          │
│                                            ┌──────────────┐                 │
│                                            │  DynamoDB    │                 │
│                                            │   (Notes)    │                 │
│                                            └──────────────┘                 │
│                                                   │                          │
│                                                   ▼                          │
│                                            ┌──────────────┐                 │
│                                            │   SQS DLQ    │                 │
│                                            │ (Failed Msgs)│                 │
│                                            └──────────────┘                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Scope

| Component             | Tier     | Criticality | DR Strategy                          |
|-----------------------|----------|-------------|--------------------------------------|
| **DynamoDB (Notes)**  | Data     | 🔴 Critical | Point-in-Time Recovery (PITR)        |
| **Cognito User Pool** | Identity | 🔴 Critical | Managed by AWS + User Export         |
| **S3 (Frontend Assets)| Static   | 🟡 Medium   | Versioning + Git Repository          |
| **Lambda Functions**  | Compute  | 🟡 Medium   | Code in Git + SAM Templates          |
| **API Gateway**       | API      | 🟡 Medium   | SAM Templates (IaC)                  |
| **CloudFront**        | CDN      | 🟢 Low      | Terraform (IaC)                      |
| **Terraform State**   | Config   | 🔴 Critical | S3 Backend + Versioning              |
| **CloudWatch Logs**   | Logs     | 🟢 Low      | Export to S3 (optional)              |

---

## Recovery Objectives

### RPO (Recovery Point Objective)

**Definition**: Maximum acceptable amount of data loss measured in time.

| Component                     | RPO   | Justification |
|-------------------------------|-------|---------------|
| **DynamoDB (User Notes)**     | **5 minutes** | PITR provides continuous backup with 5-min granularity |
| **Cognito User Pool**         | **24 hours** | User accounts rarely change; daily export sufficient |
| **S3 Frontend Assets**        | **0 (Zero)** | Assets stored in Git; can rebuild instantly |
| **Terraform State**           | **Immediate** | S3 versioning with DynamoDB locking |
| **Application Configuration** | **0 (Zero)** | All config stored in Git (IaC) |

### RTO (Recovery Time Objective)

**Definition**: Maximum acceptable time to restore service after a disaster.

| Component                     | RTO   | Recovery Method |
|-------------------------------|-------|-----------------|
| **DynamoDB (User Notes)**     | **1 hour** | Restore from PITR to new table |
| **Cognito User Pool**         | **4 hours** | AWS managed recovery or recreate + import |
| **Lambda Functions**          | **15 minutes** | Redeploy via SAM (`sam deploy`) |
| **API Gateway**               | **15 minutes** | Recreated automatically with SAM |
| **CloudFront + S3 (Frontend)** | **30 minutes** | Terraform apply + S3 sync |
| **Full Application**          | **2 hours** | Complete infrastructure + data restore |

### Recovery Priority Order

```
Priority 1 (Critical - Restore First)
├── 1.1 DynamoDB Table (user data)
├── 1.2 Cognito User Pool (authentication)
└── 1.3 Terraform State (infrastructure config)

Priority 2 (High - Restore Second)  
├── 2.1 Lambda Functions (API backend)
├── 2.2 API Gateway (API endpoints)
└── 2.3 SQS Dead Letter Queue (failed messages)

Priority 3 (Medium - Restore Third)
├── 3.1 S3 Bucket (frontend assets)
├── 3.2 CloudFront Distribution (CDN)
└── 3.3 Route53 Records (DNS)

Priority 4 (Low - Restore Last)
├── 4.1 CloudWatch Alarms (monitoring)
├── 4.2 WAF Rules (security)
└── 4.3 Budget Alerts (cost control)
```

---

## Backup Scope & Strategy

### 1. DynamoDB - User Notes (CRITICAL)

**Backup Method**: Point-in-Time Recovery (PITR)
**Frequency**: Continuous (automatic)
**Retention**: 35 days
**Location**: AWS managed

**Current Status**: 
```hcl
# infra/terraform/modules/dynamodb/main.tf
# NOTE: PITR is currently DISABLED to reduce costs
# checkov:skip=CKV_AWS_28:Reason: User explicitly opted out of Point-in-Time Recovery
```

**⚠️ RECOMMENDATION**: Enable PITR for production environments:

```hcl
# Add to DynamoDB table configuration
point_in_time_recovery {
  enabled = true
}
```

**Backup Verification**:
```powershell
# Check PITR status
aws dynamodb describe-continuous-backups `
  --table-name d1-personal-note-main-notes

# Expected output (when enabled):
# "PointInTimeRecoveryStatus": "ENABLED"
# "EarliestRestorableDateTime": "2025-12-XX..."
# "LatestRestorableDateTime": "2025-12-XX..."
```

**Manual Backup (On-Demand)**:
```powershell
# Create on-demand backup before major changes
aws dynamodb create-backup `
  --table-name d1-personal-note-main-notes `
  --backup-name "d1-notes-backup-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"

# List existing backups
aws dynamodb list-backups `
  --table-name d1-personal-note-main-notes
```

---

### 2. Cognito User Pool (CRITICAL)

**Backup Method**: User Export via AWS CLI / Terraform State
**Frequency**: Weekly (manual) or after significant user growth
**Retention**: 90 days
**Location**: S3 bucket (encrypted)

**Export Users**:
```powershell
# Export all users from Cognito User Pool
$userPoolId = "ap-southeast-1_XXXXXXXXX"
$users = aws cognito-idp list-users --user-pool-id $userPoolId --output json

# Save to file
$users | Out-File -FilePath "cognito-users-backup-$(Get-Date -Format 'yyyy-MM-dd').json"

# Upload to S3 (encrypted)
aws s3 cp `
  "cognito-users-backup-$(Get-Date -Format 'yyyy-MM-dd').json" `
  "s3://d1-personal-note-backups/cognito/" `
  --sse AES256
```

**Cognito Configuration Backup**:
```powershell
# Export User Pool configuration
aws cognito-idp describe-user-pool `
  --user-pool-id $userPoolId `
  --output json > cognito-pool-config.json

# Export App Client configuration  
aws cognito-idp describe-user-pool-client `
  --user-pool-id $userPoolId `
  --client-id "your-client-id" `
  --output json > cognito-client-config.json
```

**Terraform State Backup**:
- Cognito configuration is stored in Terraform state
- State file is backed up via S3 versioning
- Location: `s3://d1-personal-note-tfstate/terraform.tfstate`

---

### 3. S3 Frontend Assets (MEDIUM)

**Backup Method**: S3 Versioning + Git Repository
**Frequency**: Every deployment
**Retention**: 180 days (via lifecycle policy)
**Location**: 
- Primary: S3 bucket with versioning
- Secondary: Git repository (source files)

**Current Configuration**:
```hcl
# infra/terraform/modules/hosting/main.tf
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}
```

**Lifecycle Policy** (Already Implemented):
- Non-current versions → Standard-IA after 30 days
- Non-current versions → Glacier after 90 days
- Non-current versions → Deleted after 180 days

**Recovery Strategy**:
- Source files in Git: Can rebuild and deploy anytime
- S3 versioning: Rollback to previous version if needed

---

### 4. Lambda Functions (MEDIUM)

**Backup Method**: Git Repository + SAM Templates
**Frequency**: Every commit/deployment
**Retention**: Git history (permanent)
**Location**: GitHub repository

**Backup Includes**:
- Source code: `api/src/`
- SAM template: `api/template.yaml`
- Dependencies: `api/package.json`
- Tests: `api/tests/`

**Deployment Artifacts**:
```powershell
# List Lambda versions (rollback targets)
aws lambda list-versions-by-function `
  --function-name d1-personal-note-read-main

# List deployed aliases
aws lambda list-aliases `
  --function-name d1-personal-note-read-main
```

---

### 5. Terraform State (CRITICAL)

**Backup Method**: S3 Versioning + DynamoDB Locking
**Frequency**: Automatic (every state change)
**Retention**: S3 versioning (all versions retained)
**Location**: `s3://d1-personal-note-tfstate/`

**Backup Verification**:
```powershell
# List state file versions
aws s3api list-object-versions `
  --bucket d1-personal-note-tfstate `
  --prefix terraform.tfstate

# Download specific version
aws s3api get-object `
  --bucket d1-personal-note-tfstate `
  --key terraform.tfstate `
  --version-id "VersionIdHere" `
  terraform-state-backup.tfstate
```

---

### 6. CloudWatch Logs (LOW)

**Backup Method**: Export to S3 (optional)
**Frequency**: On-demand or scheduled
**Retention**: 30 days (in CloudWatch)
**Location**: S3 bucket (if exported)

**Export Logs**:
```powershell
# Create export task
aws logs create-export-task `
  --log-group-name "/aws/lambda/d1-personal-note-read-main" `
  --from (Get-Date).AddDays(-7).ToFileTimeUtc() `
  --to (Get-Date).ToFileTimeUtc() `
  --destination "d1-personal-note-log-exports" `
  --destination-prefix "lambda-read/"
```

---

## Restore Procedures

### Procedure 1: Restore DynamoDB from PITR

**When to Use**: 
- Accidental data deletion
- Data corruption
- Ransomware attack on data

**Prerequisites**:
- PITR must be enabled
- Know the target restore time

**Steps**:

```powershell
# Step 1: Identify restore point
aws dynamodb describe-continuous-backups `
  --table-name d1-personal-note-main-notes

# Note the EarliestRestorableDateTime and LatestRestorableDateTime

# Step 2: Restore to a new table
$restoreTime = "2025-12-28T10:00:00Z"  # Replace with target time
aws dynamodb restore-table-to-point-in-time `
  --source-table-name d1-personal-note-main-notes `
  --target-table-name d1-personal-note-main-notes-restored `
  --restore-date-time $restoreTime

# Step 3: Wait for restore to complete
aws dynamodb describe-table `
  --table-name d1-personal-note-main-notes-restored

# Wait until TableStatus = "ACTIVE"

# Step 4: Verify data integrity
aws dynamodb scan `
  --table-name d1-personal-note-main-notes-restored `
  --select COUNT

# Step 5: Update application to point to restored table
# Option A: Update Lambda environment variable
aws lambda update-function-configuration `
  --function-name d1-personal-note-read-main `
  --environment Variables='{TABLE_NAME=d1-personal-note-main-notes-restored}'

aws lambda update-function-configuration `
  --function-name d1-personal-note-write-main `
  --environment Variables='{TABLE_NAME=d1-personal-note-main-notes-restored}'

# Option B: Or rename tables (requires downtime)
# - Delete original table (after confirming restored data is correct)
# - Rename restored table to original name (not directly supported; use parallel table)

# Step 6: Verify application functionality
# Test API endpoints with sample requests
```

**Rollback**:
```powershell
# If restore was incorrect, revert Lambda to original table
aws lambda update-function-configuration `
  --function-name d1-personal-note-read-main `
  --environment Variables='{TABLE_NAME=d1-personal-note-main-notes}'

aws lambda update-function-configuration `
  --function-name d1-personal-note-write-main `
  --environment Variables='{TABLE_NAME=d1-personal-note-main-notes}'
```

---

### Procedure 2: Restore DynamoDB from On-Demand Backup

**When to Use**:
- PITR not enabled
- Need to restore from a specific backup

**Steps**:

```powershell
# Step 1: List available backups
aws dynamodb list-backups `
  --table-name d1-personal-note-main-notes

# Step 2: Restore from backup
$backupArn = "arn:aws:dynamodb:ap-southeast-1:123456789:table/d1-personal-note-main-notes/backup/01234567890"
aws dynamodb restore-table-from-backup `
  --target-table-name d1-personal-note-main-notes-restored `
  --backup-arn $backupArn

# Step 3-6: Same as PITR restore procedure above
```

---

### Procedure 3: Restore Lambda Functions

**When to Use**:
- Lambda code corrupted or deleted
- Need to rollback to previous version

**Option A: Redeploy from Git**:
```powershell
# Step 1: Clone repository (if needed)
git clone https://github.com/your-org/d1-personal-note.git
cd d1-personal-note/api

# Step 2: Install dependencies
npm ci

# Step 3: Build TypeScript
npm run build

# Step 4: Deploy with SAM
sam deploy `
  --stack-name d1-personal-note-api-main `
  --parameter-overrides `
    Environment=main `
    DynamoDBTableName=d1-personal-note-main-notes `
    UserPoolId=ap-southeast-1_XXXXXXXXX `
    Project=d1-personal-note
```

**Option B: Rollback to Previous Lambda Version**:
```powershell
# Step 1: List available versions
aws lambda list-versions-by-function `
  --function-name d1-personal-note-read-main

# Step 2: Update alias to previous version
aws lambda update-alias `
  --function-name d1-personal-note-read-main `
  --name live `
  --function-version 5  # Replace with target version
```

---

### Procedure 4: Restore Frontend (S3 + CloudFront)

**When to Use**:
- Frontend files corrupted or deleted
- Need to rollback to previous version

**Option A: Rebuild and Deploy from Git**:
```powershell
# Step 1: Clone repository
git clone https://github.com/your-org/d1-personal-note.git
cd d1-personal-note/frontend

# Step 2: Install dependencies
npm ci

# Step 3: Build production assets
npm run build

# Step 4: Deploy to S3
aws s3 sync dist/ s3://p1-serverless-web-app-main-hosting/ --delete

# Step 5: Invalidate CloudFront cache
aws cloudfront create-invalidation `
  --distribution-id EXXXXXXXXXXXXX `
  --paths "/*"
```

**Option B: Restore S3 Object to Previous Version**:
```powershell
# Step 1: List object versions
aws s3api list-object-versions `
  --bucket p1-serverless-web-app-main-hosting `
  --prefix index.html

# Step 2: Copy previous version as current
aws s3api copy-object `
  --bucket p1-serverless-web-app-main-hosting `
  --copy-source "p1-serverless-web-app-main-hosting/index.html?versionId=OLD_VERSION_ID" `
  --key index.html

# Step 3: Invalidate CloudFront cache
aws cloudfront create-invalidation `
  --distribution-id EXXXXXXXXXXXXX `
  --paths "/index.html"
```

---

### Procedure 5: Restore Full Infrastructure (Terraform)

**When to Use**:
- Complete infrastructure failure
- Cross-region disaster recovery
- Infrastructure deleted/corrupted

**Steps**:

```powershell
# Step 1: Clone repository
git clone https://github.com/your-org/d1-personal-note.git
cd d1-personal-note/infra/terraform

# Step 2: Initialize Terraform with existing state
terraform init -backend-config=environments/main/backend.hcl

# Step 3: Verify state is intact
terraform state list

# Step 4: Plan changes
terraform plan -var-file=environments/main/terraform.tfvars -out=recovery.plan

# Step 5: Apply infrastructure
terraform apply recovery.plan

# Step 6: Verify infrastructure
terraform output

# Step 7: Deploy API (SAM)
cd ../../api
sam deploy --parameter-overrides Environment=main

# Step 8: Deploy Frontend
cd ../frontend
npm ci && npm run build
aws s3 sync dist/ s3://$(terraform output -raw hosting_bucket_name)/ --delete
```

---

### Procedure 6: Restore Cognito User Pool

**When to Use**:
- User Pool accidentally deleted
- Need to migrate to new User Pool

**Steps**:

```powershell
# Step 1: Recreate User Pool via Terraform
cd infra/terraform
terraform apply -var-file=environments/main/terraform.tfvars -target=module.auth

# Step 2: Import users from backup
$backup = Get-Content "cognito-users-backup-2025-12-28.json" | ConvertFrom-Json

foreach ($user in $backup.Users) {
    aws cognito-idp admin-create-user `
      --user-pool-id NEW_POOL_ID `
      --username $user.Username `
      --user-attributes $user.Attributes
}

# Note: Passwords cannot be imported; users must reset passwords

# Step 3: Update API Gateway to use new User Pool
# Update template.yaml with new UserPoolId and redeploy
cd ../api
sam deploy --parameter-overrides Environment=main UserPoolId=NEW_POOL_ID

# Step 4: Update frontend configuration
# Update .env.development with new Cognito settings
```

---

### Procedure 7: Restore Terraform State

**When to Use**:
- Terraform state file corrupted or deleted
- State drift detected

**Option A: Restore from S3 Version History**:
```powershell
# Step 1: List state versions
aws s3api list-object-versions `
  --bucket d1-personal-note-tfstate `
  --prefix terraform.tfstate

# Step 2: Download previous version
aws s3api get-object `
  --bucket d1-personal-note-tfstate `
  --key terraform.tfstate `
  --version-id VERSION_ID_HERE `
  terraform.tfstate.backup

# Step 3: Upload as current state (CAUTION!)
aws s3 cp terraform.tfstate.backup `
  s3://d1-personal-note-tfstate/terraform.tfstate

# Step 4: Re-initialize and verify
terraform init -backend-config=environments/main/backend.hcl
terraform plan -var-file=environments/main/terraform.tfvars
```

**Option B: Import Existing Resources**:
```powershell
# Step 1: Initialize with fresh state
terraform init -backend-config=environments/main/backend.hcl

# Step 2: Import resources one by one
terraform import module.database.aws_dynamodb_table.main["notes"] d1-personal-note-main-notes
terraform import module.auth.aws_cognito_user_pool.main ap-southeast-1_XXXXXXXXX
terraform import module.hosting.aws_s3_bucket.website p1-serverless-web-app-main-hosting
# ... continue for all resources

# Step 3: Verify import
terraform plan -var-file=environments/main/terraform.tfvars
```

---

## Disaster Scenarios & Runbooks

### Scenario 1: Accidental Data Deletion

**Impact**: Users lose notes data  
**Severity**: P0 - Critical  
**RTO**: 1 hour  
**RPO**: 5 minutes (with PITR) / Last backup (without PITR)

**Detection**:
- User reports
- DynamoDB item count drops significantly
- CloudWatch ItemCount metric anomaly

**Response**:
1. **STOP WRITES** immediately
   ```powershell
   aws lambda update-function-configuration `
     --function-name d1-personal-note-write-main `
     --environment Variables='{MAINTENANCE_MODE=true}'
   ```
2. Identify deletion time from CloudTrail
3. Execute [Procedure 1: Restore DynamoDB from PITR](#procedure-1-restore-dynamodb-from-pitr)
4. Verify data integrity
5. Resume writes
6. Conduct post-incident review

---

### Scenario 2: Complete AWS Region Outage

**Impact**: Complete service outage  
**Severity**: P0 - Critical  
**RTO**: 4 hours  
**RPO**: 5 minutes (DynamoDB PITR) / Varies for other components

**Detection**:
- AWS Service Health Dashboard
- All endpoints unreachable
- CloudWatch data gaps

**Response**:
1. Confirm region outage via AWS Status Page
2. **If cross-region DR is set up**:
   - Activate DR region resources
   - Update DNS to point to DR region
3. **If single-region**:
   - Wait for AWS to restore services
   - Once restored, verify all components
   - No data should be lost (AWS handles region recovery)

**Future Enhancement**:
- Implement Global Tables for DynamoDB (automatic cross-region replication)
- Deploy infrastructure to secondary region
- Use Route53 health checks for automatic failover

---

### Scenario 3: Ransomware/Malicious Encryption

**Impact**: Data encrypted by attacker  
**Severity**: P0 - Critical  
**RTO**: 2 hours  
**RPO**: 5 minutes (with PITR)

**Detection**:
- Users report unreadable data
- Anomalous write patterns in CloudWatch
- Ransom note in S3/DynamoDB

**Response**:
1. **IMMEDIATE ISOLATION**
   ```powershell
   # Disable all write access
   aws lambda delete-function-url-config --function-name d1-personal-note-write-main
   
   # Disable API Gateway stage
   aws apigateway update-stage `
     --rest-api-id API_ID `
     --stage-name main `
     --patch-operations op=replace,path=/deploymentId,value=''
   ```
2. **Rotate ALL credentials**
   - IAM access keys
   - Cognito user passwords (force reset)
3. Execute [Procedure 1: Restore DynamoDB from PITR](#procedure-1-restore-dynamodb-from-pitr) to pre-attack timestamp
4. Execute [Procedure 4: Restore Frontend](#procedure-4-restore-frontend-s3--cloudfront) to rebuild clean assets
5. Conduct security forensics
6. Report to appropriate authorities if needed

---

### Scenario 4: Terraform State Corruption

**Impact**: Cannot manage infrastructure  
**Severity**: P1 - High  
**RTO**: 1 hour  
**RPO**: Last state change

**Detection**:
- Terraform commands fail with state errors
- `terraform plan` shows unexpected destroy/create

**Response**:
1. Execute [Procedure 7: Restore Terraform State](#procedure-7-restore-terraform-state)
2. Verify state matches actual infrastructure
3. If version restore fails, import resources from AWS

---

### Scenario 5: Cognito User Pool Deletion

**Impact**: All users unable to authenticate  
**Severity**: P0 - Critical  
**RTO**: 4 hours  
**RPO**: Last user export

**Detection**:
- All authentication requests fail
- Cognito API returns "ResourceNotFoundException"

**Response**:
1. Execute [Procedure 6: Restore Cognito User Pool](#procedure-6-restore-cognito-user-pool)
2. Notify users about password reset requirement
3. Monitor for authentication success

---

## Testing & Validation

For detailed hands-on exercises with step-by-step commands and success criteria, see the **[Disaster Recovery Exercise Guide](disaster-recovery-exercise.md)**.

### DR Test Schedule

| Test Type | Frequency | Last Tested | Next Test | Owner |
|-----------|-----------|-------------|-----------|-------|
| DynamoDB PITR Restore | Quarterly | - | TBD | DevOps |
| Lambda Rollback | Monthly | - | TBD | DevOps |
| Frontend Rebuild | Monthly | - | TBD | Frontend Lead |
| Full Infrastructure Restore | Annually | - | TBD | DevOps |
| Terraform State Recovery | Semi-annually | - | TBD | DevOps |

### DR Test Procedure

**Pre-Test Checklist**:
- [ ] Notify stakeholders
- [ ] Schedule maintenance window
- [ ] Prepare rollback plan
- [ ] Document current state

**During Test**:
- [ ] Execute restore procedure
- [ ] Verify data integrity
- [ ] Test application functionality
- [ ] Measure actual RTO

**Post-Test**:
- [ ] Document results
- [ ] Update procedures if needed
- [ ] Clean up test resources
- [ ] Update DR plan

### Backup Verification Checklist

**Weekly**:
- [ ] Verify DynamoDB backup status (PITR enabled)
- [ ] Check Terraform state S3 versioning

**Monthly**:
- [ ] Perform test restore of DynamoDB table
- [ ] Verify Cognito export is current
- [ ] Test Lambda rollback procedure

**Quarterly**:
- [ ] Full DR simulation
- [ ] Update documentation
- [ ] Review and update recovery objectives

---

## Roles & Responsibilities

### DR Team Structure

| Role | Responsibility | Primary | Secondary |
|------|----------------|---------|-----------|
| **DR Coordinator** | Overall DR execution | DevOps Lead | Senior Engineer |
| **Database Recovery** | DynamoDB/data restore | Backend Lead | DevOps |
| **Application Recovery** | Lambda/API restore | Backend Lead | Frontend Lead |
| **Infrastructure Recovery** | Terraform/IaC | DevOps Lead | Backend Lead |
| **Communication** | Stakeholder updates | Project Manager | DevOps Lead |

### Contact List

| Name | Role | Phone | Email | Availability |
|------|------|-------|-------|--------------|
| [Name] | DR Coordinator | +XX XXXX XXXX | email@example.com | 24/7 |
| [Name] | Database Lead | +XX XXXX XXXX | email@example.com | Business Hours |
| [Name] | DevOps Lead | +XX XXXX XXXX | email@example.com | 24/7 |

### Escalation Path

```
DR Event Detected
       │
       ▼
On-Call Engineer (15 min response)
       │
       ▼ (If P0/P1 or no response)
DR Coordinator (30 min response)
       │
       ▼ (If no response or major incident)
Engineering Manager (1 hour response)
       │
       ▼ (If business critical)
Director/VP Engineering
```

---

## Appendix

### A. Backup Location Reference

| Component | Backup Location | Retention |
|-----------|----------------|-----------|
| DynamoDB | AWS PITR (managed) | 35 days |
| DynamoDB On-Demand | AWS Backup Vault | Configurable |
| Cognito Users | `s3://d1-personal-note-backups/cognito/` | 90 days |
| Terraform State | `s3://d1-personal-note-tfstate/` | All versions |
| Frontend Assets | S3 versioning + Git | 180 days (S3) |
| Lambda Code | Git repository | Permanent |
| CloudWatch Logs | CloudWatch | 30 days |

### B. AWS CLI Quick Reference

```powershell
# DynamoDB Status
aws dynamodb describe-table --table-name d1-personal-note-main-notes

# Lambda Status
aws lambda get-function --function-name d1-personal-note-read-main

# S3 Bucket Status
aws s3 ls s3://p1-serverless-web-app-main-hosting/

# CloudFront Status
aws cloudfront get-distribution --id EXXXXXXXXXXXXX

# Cognito Status
aws cognito-idp describe-user-pool --user-pool-id ap-southeast-1_XXXXXXXXX

# Check All CloudWatch Alarms
aws cloudwatch describe-alarms --state-value ALARM
```

### C. Recovery Time Estimates

| Recovery Procedure | Estimated Time | Dependencies |
|-------------------|----------------|--------------|
| DynamoDB PITR Restore | 30-60 min | Table size |
| Lambda Redeploy | 5-10 min | Build + deploy |
| Frontend Rebuild | 10-15 min | Build + sync + invalidation |
| Full Terraform Apply | 15-30 min | Resource count |
| Cognito User Import | 1-4 hours | User count |
| Full Application Recovery | 1-2 hours | All above |

### D. Cost of Backup Features

| Feature | Monthly Cost | Notes |
|---------|-------------|-------|
| DynamoDB PITR | ~20% of table storage | Continuous backup |
| S3 Versioning | Storage for all versions | Reduced via lifecycle |
| CloudWatch Logs | $0.50/GB ingested | 30-day retention |
| S3 Cross-Region Replication | Varies | Future enhancement |
| Global Tables | 2x write costs | Future enhancement |

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
