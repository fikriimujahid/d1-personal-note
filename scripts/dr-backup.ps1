# =============================================================================
# Disaster Recovery - Backup and Verification Script
# =============================================================================
# PURPOSE:
#   This script performs backup operations and verifies disaster recovery
#   readiness for the d1-personal-note application.
#
# USAGE:
#   .\dr-backup.ps1 -Action <action> [-Environment <env>] [-Verbose]
#
# ACTIONS:
#   verify    - Check backup status and DR readiness
#   backup    - Create on-demand backups
#   export    - Export Cognito users
#   test      - Perform DR test restore (non-destructive)
#   full      - Run all backup operations
#
# EXAMPLES:
#   .\dr-backup.ps1 -Action verify -Environment main
#   .\dr-backup.ps1 -Action backup -Environment main
#   .\dr-backup.ps1 -Action full -Environment main
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("verify", "backup", "export", "test", "full")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "main")]
    [string]$Environment = "main",
    
    [Parameter(Mandatory = $false)]
    [string]$Project = "d1-personal-note",
    
    [Parameter(Mandatory = $false)]
    [string]$Region = "ap-southeast-1",
    
    [Parameter(Mandatory = $false)]
    [string]$BackupBucket = ""
)

# =============================================================================
# Configuration
# =============================================================================

$ErrorActionPreference = "Stop"
$TableName = "$Project-$Environment-notes"
$BackupPrefix = "dr-backup"
$DateStamp = Get-Date -Format "yyyy-MM-dd-HHmm"

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }

# =============================================================================
# Helper Functions
# =============================================================================

function Test-AWSCredentials {
    try {
        $identity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
        Write-Success "✓ AWS credentials valid: $($identity.Arn)"
        return $true
    }
    catch {
        Write-Error "✗ AWS credentials not configured or expired"
        return $false
    }
}

function Get-DynamoDBPITRStatus {
    param([string]$Table)
    
    try {
        $backup = aws dynamodb describe-continuous-backups `
            --table-name $Table `
            --region $Region `
            --output json 2>$null | ConvertFrom-Json
        
        $pitr = $backup.ContinuousBackupsDescription.PointInTimeRecoveryDescription
        return @{
            Enabled = $pitr.PointInTimeRecoveryStatus -eq "ENABLED"
            EarliestRestoreTime = $pitr.EarliestRestorableDateTime
            LatestRestoreTime = $pitr.LatestRestorableDateTime
        }
    }
    catch {
        return @{ Enabled = $false; Error = $_.Exception.Message }
    }
}

function Get-DynamoDBTableStatus {
    param([string]$Table)
    
    try {
        $describe = aws dynamodb describe-table `
            --table-name $Table `
            --region $Region `
            --output json 2>$null | ConvertFrom-Json
        
        $table = $describe.Table
        return @{
            Status = $table.TableStatus
            ItemCount = $table.ItemCount
            SizeBytes = $table.TableSizeBytes
            DeletionProtection = $table.DeletionProtectionEnabled
        }
    }
    catch {
        return @{ Status = "NOT_FOUND"; Error = $_.Exception.Message }
    }
}

# =============================================================================
# Action: Verify DR Readiness
# =============================================================================

function Invoke-Verify {
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "  DISASTER RECOVERY - VERIFICATION REPORT" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  Environment: $Environment"
    Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    $issues = @()
    
    # 1. Check AWS Credentials
    Write-Host "`n[1/5] Checking AWS Credentials..." -ForegroundColor White
    if (-not (Test-AWSCredentials)) {
        $issues += "AWS credentials not valid"
    }
    
    # 2. Check DynamoDB Table Status
    Write-Host "`n[2/5] Checking DynamoDB Table Status..." -ForegroundColor White
    $tableStatus = Get-DynamoDBTableStatus -Table $TableName
    if ($tableStatus.Status -eq "ACTIVE") {
        Write-Success "  ✓ Table '$TableName' is ACTIVE"
        Write-Info "    Items: $($tableStatus.ItemCount)"
        Write-Info "    Size: $([math]::Round($tableStatus.SizeBytes / 1KB, 2)) KB"
        if ($tableStatus.DeletionProtection) {
            Write-Success "  ✓ Deletion protection: ENABLED"
        } else {
            Write-Warning "  ⚠ Deletion protection: DISABLED (recommended for production)"
            $issues += "Deletion protection disabled for $TableName"
        }
    } else {
        Write-Error "  ✗ Table '$TableName' status: $($tableStatus.Status)"
        $issues += "DynamoDB table not active: $($tableStatus.Status)"
    }
    
    # 3. Check PITR Status
    Write-Host "`n[3/5] Checking Point-in-Time Recovery (PITR)..." -ForegroundColor White
    $pitr = Get-DynamoDBPITRStatus -Table $TableName
    if ($pitr.Enabled) {
        Write-Success "  ✓ PITR is ENABLED"
        Write-Info "    Earliest restore: $($pitr.EarliestRestoreTime)"
        Write-Info "    Latest restore: $($pitr.LatestRestoreTime)"
        
        # Calculate restore window
        $earliest = [datetime]::Parse($pitr.EarliestRestoreTime)
        $latest = [datetime]::Parse($pitr.LatestRestoreTime)
        $window = ($latest - $earliest).TotalDays
        Write-Info "    Restore window: $([math]::Round($window, 1)) days"
    } else {
        Write-Error "  ✗ PITR is DISABLED"
        Write-Error "    ⚠ CRITICAL: Cannot restore to point-in-time!"
        $issues += "PITR not enabled for $TableName"
    }
    
    # 4. Check On-Demand Backups
    Write-Host "`n[4/5] Checking On-Demand Backups..." -ForegroundColor White
    try {
        $backups = aws dynamodb list-backups `
            --table-name $TableName `
            --region $Region `
            --output json 2>$null | ConvertFrom-Json
        
        $backupCount = $backups.BackupSummaries.Count
        if ($backupCount -gt 0) {
            Write-Success "  ✓ Found $backupCount on-demand backup(s)"
            $latest = $backups.BackupSummaries | Sort-Object BackupCreationDateTime -Descending | Select-Object -First 1
            Write-Info "    Latest: $($latest.BackupName)"
            Write-Info "    Created: $($latest.BackupCreationDateTime)"
        } else {
            Write-Warning "  ⚠ No on-demand backups found"
            Write-Info "    Recommendation: Create periodic on-demand backups"
        }
    }
    catch {
        Write-Warning "  ⚠ Could not retrieve backup information"
    }
    
    # 5. Check Terraform State
    Write-Host "`n[5/5] Checking Terraform State Backend..." -ForegroundColor White
    $tfBackendFile = Join-Path $PSScriptRoot "..\infra\terraform\environments\$Environment\backend.hcl"
    if (Test-Path $tfBackendFile) {
        Write-Success "  ✓ Terraform backend config exists"
        $content = Get-Content $tfBackendFile -Raw
        if ($content -match 'bucket\s*=\s*"([^"]+)"') {
            $stateBucket = $Matches[1]
            Write-Info "    State bucket: $stateBucket"
            
            # Check if state file exists
            try {
                $stateVersions = aws s3api list-object-versions `
                    --bucket $stateBucket `
                    --prefix terraform.tfstate `
                    --max-items 5 `
                    --output json 2>$null | ConvertFrom-Json
                
                if ($stateVersions.Versions.Count -gt 0) {
                    Write-Success "  ✓ State file found with versioning"
                    Write-Info "    Versions available: $($stateVersions.Versions.Count)+"
                }
            }
            catch {
                Write-Warning "  ⚠ Could not verify state file"
            }
        }
    } else {
        Write-Warning "  ⚠ Terraform backend config not found"
    }
    
    # Summary
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "  VERIFICATION SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    if ($issues.Count -eq 0) {
        Write-Success "`n  ✓ All DR checks passed! System is recovery-ready.`n"
    } else {
        Write-Warning "`n  ⚠ Issues found: $($issues.Count)`n"
        foreach ($issue in $issues) {
            Write-Error "    - $issue"
        }
        Write-Host ""
    }
    
    return $issues.Count -eq 0
}

# =============================================================================
# Action: Create On-Demand Backup
# =============================================================================

function Invoke-Backup {
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "  CREATING ON-DEMAND BACKUP" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    $backupName = "$BackupPrefix-$Environment-$DateStamp"
    
    Write-Info "Creating backup: $backupName"
    Write-Info "Table: $TableName"
    
    try {
        $result = aws dynamodb create-backup `
            --table-name $TableName `
            --backup-name $backupName `
            --region $Region `
            --output json | ConvertFrom-Json
        
        Write-Success "`n✓ Backup created successfully!"
        Write-Info "  Backup Name: $($result.BackupDetails.BackupName)"
        Write-Info "  Backup ARN: $($result.BackupDetails.BackupArn)"
        Write-Info "  Status: $($result.BackupDetails.BackupStatus)"
        
        return $true
    }
    catch {
        Write-Error "`n✗ Failed to create backup: $($_.Exception.Message)"
        return $false
    }
}

# =============================================================================
# Action: Export Cognito Users
# =============================================================================

function Invoke-Export {
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "  EXPORTING COGNITO USERS" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Find Cognito User Pool
    try {
        $pools = aws cognito-idp list-user-pools `
            --max-results 10 `
            --region $Region `
            --output json | ConvertFrom-Json
        
        $pool = $pools.UserPools | Where-Object { $_.Name -like "*$Project*$Environment*" } | Select-Object -First 1
        
        if (-not $pool) {
            Write-Warning "No Cognito User Pool found for $Project-$Environment"
            return $false
        }
        
        $poolId = $pool.Id
        Write-Info "Found User Pool: $($pool.Name) ($poolId)"
        
        # Export users
        $exportFile = "cognito-users-$Environment-$DateStamp.json"
        
        Write-Info "Exporting users to: $exportFile"
        
        $users = aws cognito-idp list-users `
            --user-pool-id $poolId `
            --region $Region `
            --output json
        
        $users | Out-File -FilePath $exportFile -Encoding UTF8
        
        $userCount = ($users | ConvertFrom-Json).Users.Count
        Write-Success "`n✓ Exported $userCount users to $exportFile"
        
        # Upload to S3 if bucket specified
        if ($BackupBucket) {
            Write-Info "Uploading to S3: s3://$BackupBucket/cognito/"
            aws s3 cp $exportFile "s3://$BackupBucket/cognito/$exportFile" --sse AES256
            Write-Success "✓ Uploaded to S3"
        }
        
        return $true
    }
    catch {
        Write-Error "`n✗ Failed to export users: $($_.Exception.Message)"
        return $false
    }
}

# =============================================================================
# Action: Test DR Restore (Non-Destructive)
# =============================================================================

function Invoke-Test {
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "  DR TEST RESTORE (Non-Destructive)" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Check PITR first
    $pitr = Get-DynamoDBPITRStatus -Table $TableName
    if (-not $pitr.Enabled) {
        Write-Error "PITR is not enabled. Cannot perform test restore."
        return $false
    }
    
    $testTableName = "$TableName-dr-test-$DateStamp"
    $restoreTime = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-Warning "This will create a test table: $testTableName"
    Write-Warning "Restore point: $restoreTime"
    Write-Host ""
    
    $confirm = Read-Host "Proceed with test restore? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Info "Test restore cancelled."
        return $false
    }
    
    try {
        Write-Info "Starting test restore..."
        
        $result = aws dynamodb restore-table-to-point-in-time `
            --source-table-name $TableName `
            --target-table-name $testTableName `
            --restore-date-time $restoreTime `
            --region $Region `
            --output json | ConvertFrom-Json
        
        Write-Success "`n✓ Test restore initiated!"
        Write-Info "  Target Table: $testTableName"
        Write-Info "  Restore Time: $restoreTime"
        Write-Info "  Status: $($result.TableDescription.TableStatus)"
        
        Write-Warning "`n⚠ Remember to delete the test table after verification:"
        Write-Warning "  aws dynamodb delete-table --table-name $testTableName"
        
        return $true
    }
    catch {
        Write-Error "`n✗ Test restore failed: $($_.Exception.Message)"
        return $false
    }
}

# =============================================================================
# Main Execution
# =============================================================================

Write-Host "`n" + "=" * 60 -ForegroundColor Magenta
Write-Host "  D1-PERSONAL-NOTE - DISASTER RECOVERY SCRIPT" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Magenta

switch ($Action) {
    "verify" {
        $success = Invoke-Verify
        exit $(if ($success) { 0 } else { 1 })
    }
    "backup" {
        $success = Invoke-Backup
        exit $(if ($success) { 0 } else { 1 })
    }
    "export" {
        $success = Invoke-Export
        exit $(if ($success) { 0 } else { 1 })
    }
    "test" {
        $success = Invoke-Test
        exit $(if ($success) { 0 } else { 1 })
    }
    "full" {
        Write-Info "Running full DR operations..."
        
        $verifyOk = Invoke-Verify
        if (-not $verifyOk) {
            Write-Warning "Verification found issues, but continuing with backups..."
        }
        
        $backupOk = Invoke-Backup
        $exportOk = Invoke-Export
        
        Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
        Write-Host "  FULL BACKUP SUMMARY" -ForegroundColor Cyan
        Write-Host "=" * 60 -ForegroundColor Cyan
        Write-Host "  Verification: $(if ($verifyOk) { '✓ Pass' } else { '⚠ Issues' })"
        Write-Host "  DynamoDB Backup: $(if ($backupOk) { '✓ Success' } else { '✗ Failed' })"
        Write-Host "  Cognito Export: $(if ($exportOk) { '✓ Success' } else { '✗ Failed' })"
        Write-Host ""
        
        exit $(if ($backupOk) { 0 } else { 1 })
    }
}
