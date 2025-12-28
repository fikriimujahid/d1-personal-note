# ============================================================================
# Incident Response Toolkit - Main Script
# ============================================================================
# This script provides automated incident response capabilities for the
# d1-personal-note application.
#
# Usage:
#   .\incident-response.ps1 -Action [detect|investigate|rollback|restore] [options]
#
# Examples:
#   .\incident-response.ps1 -Action detect
#   .\incident-response.ps1 -Action investigate -Service lambda -FunctionName d1-personal-note-read-main
#   .\incident-response.ps1 -Action rollback -Service api
#   .\incident-response.ps1 -Action restore -Service dynamodb -TableName notes -RestoreTime "2025-12-28T00:00:00Z"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('detect', 'investigate', 'rollback', 'restore', 'health-check')]
    [string]$Action,

    [ValidateSet('lambda', 'api', 'dynamodb', 'cognito', 'cloudfront', 'all')]
    [string]$Service = 'all',

    [string]$FunctionName,
    [string]$TableName,
    [string]$RestoreTime,
    [string]$Environment = 'main',
    [string]$Region = 'ap-southeast-1',
    [int]$LookbackHours = 1
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = 'Stop'
$Project = "d1-personal-note"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Colors for output
$Colors = @{
    Success = 'Green'
    Warning = 'Yellow'
    Error   = 'Red'
    Info    = 'Cyan'
}

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Level = 'Info'
    )
    
    $color = $Colors[$Level]
    $prefix = switch ($Level) {
        'Success' { '[OK]' }
        'Warning' { '[WARN]' }
        'Error'   { '[ERR]' }
        'Info'    { '[INFO]' }
    }
    
    Write-Host "[$Timestamp] $prefix $Message" -ForegroundColor $color
}

function Get-StartTime {
    return (Get-Date).AddHours(-$LookbackHours).ToUniversalTime()
}

function Get-EndTime {
    return (Get-Date).ToUniversalTime()
}

# ============================================================================
# Detection Functions
# ============================================================================

function Test-AlarmStatus {
    Write-Log "Checking CloudWatch alarms..." -Level Info
    
    try {
        $alarmArgs = @(
            "cloudwatch", "describe-alarms",
            "--state-value", "ALARM",
            "--query", "MetricAlarms[?starts_with(AlarmName, '${Project}-${Environment}')]",
            "--output", "json"
        )
        $alarms = aws @alarmArgs | ConvertFrom-Json
        
        if ($alarms.Count -eq 0) {
            Write-Log "No active alarms found" -Level Success
            return $true
        }
        
        Write-Log "Found $($alarms.Count) active alarm(s)" -Level Warning
        
        foreach ($alarm in $alarms) {
            Write-Host "`n-- Alarm: $($alarm.AlarmName)" -ForegroundColor Yellow
            Write-Host "   State: $($alarm.StateValue)"
            Write-Host "   Reason: $($alarm.StateReason)"
            Write-Host "   Updated: $($alarm.StateUpdatedTimestamp)"
            Write-Host "----------------------------------------" -ForegroundColor Yellow
        }
        
        return $false
    }
    catch {
        Write-Log "Error checking alarms: $_" -Level Error
        throw
    }
}

function Test-LambdaHealth {
    Write-Log "Checking Lambda function health..." -Level Info
    
    $functions = @(
        "$Project-read-$Environment",
        "$Project-write-$Environment"
    )
    
    foreach ($func in $functions) {
        try {
            # Get function configuration
            $configArgs = @(
                "lambda", "get-function",
                "--function-name", $func,
                "--query", "Configuration.[FunctionName,State,LastUpdateStatus]",
                "--output", "json"
            )
            $config = aws @configArgs | ConvertFrom-Json
            
            # Get error metrics
            $metricArgs = @(
                "cloudwatch", "get-metric-statistics",
                "--namespace", "AWS/Lambda",
                "--metric-name", "Errors",
                "--dimensions", "Name=FunctionName,Value=$func",
                "--start-time", (Get-StartTime).ToString("o"),
                "--end-time", (Get-EndTime).ToString("o"),
                "--period", "300",
                "--statistics", "Sum",
                "--query", "Datapoints[0].Sum",
                "--output", "text"
            )
            $errors = aws @metricArgs
            
            if ($errors -eq "None" -or $null -eq $errors) { $errors = 0 }
            
            Write-Host "`n-- Function: $func" -ForegroundColor Cyan
            Write-Host "   State: $($config[1])"
            Write-Host "   Update Status: $($config[2])"
            Write-Host "   Errors (last $LookbackHours hr): $errors"
            
            if ($errors -gt 0) {
                Write-Host "----------------------------------------" -ForegroundColor Yellow
            } else {
                Write-Host "----------------------------------------" -ForegroundColor Green
            }
        }
        catch {
            Write-Log "Error checking function $func : $_" -Level Error
        }
    }
}

function Test-DynamoDBHealth {
    Write-Log "Checking DynamoDB table health..." -Level Info
    
    $tableName = "$Project-$Environment-notes"
    
    try {
        # Get table status
        $tableArgs = @(
            "dynamodb", "describe-table",
            "--table-name", $tableName,
            "--query", "Table.[TableName,TableStatus,ItemCount]",
            "--output", "json"
        )
        $table = aws @tableArgs | ConvertFrom-Json
        
        # Get throttle events
        $readArgs = @(
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/DynamoDB",
            "--metric-name", "ReadThrottleEvents",
            "--dimensions", "Name=TableName,Value=$tableName",
            "--start-time", (Get-StartTime).ToString("o"),
            "--end-time", (Get-EndTime).ToString("o"),
            "--period", "300",
            "--statistics", "Sum",
            "--query", "sum(Datapoints[].Sum)",
            "--output", "text"
        )
        $readThrottle = aws @readArgs
        
        $writeArgs = @(
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/DynamoDB",
            "--metric-name", "WriteThrottleEvents",
            "--dimensions", "Name=TableName,Value=$tableName",
            "--start-time", (Get-StartTime).ToString("o"),
            "--end-time", (Get-EndTime).ToString("o"),
            "--period", "300",
            "--statistics", "Sum",
            "--query", "sum(Datapoints[].Sum)",
            "--output", "text"
        )
        $writeThrottle = aws @writeArgs
        
        if ($readThrottle -eq "None" -or $null -eq $readThrottle) { $readThrottle = 0 }
        if ($writeThrottle -eq "None" -or $null -eq $writeThrottle) { $writeThrottle = 0 }
        
        Write-Host "`n-- Table: $tableName" -ForegroundColor Cyan
        Write-Host "   Status: $($table[1])"
        Write-Host "   Item Count: $($table[2])"
        Write-Host "   Read Throttles: $readThrottle"
        Write-Host "   Write Throttles: $writeThrottle"
        
        if ($readThrottle -gt 0 -or $writeThrottle -gt 0) {
            Write-Host "----------------------------------------" -ForegroundColor Yellow
        } else {
            Write-Host "----------------------------------------" -ForegroundColor Green
        }
    }
    catch {
        Write-Log "Error checking table $tableName : $_" -Level Error
    }
}

function Test-APIHealth {
    Write-Log "Checking API Gateway health..." -Level Info
    
    $apiName = "$Project-api-$Environment"
    
    try {
        # Get 5xx errors
        $errorArgs = @(
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/ApiGateway",
            "--metric-name", "5XXError",
            "--dimensions", "Name=ApiName,Value=$apiName", "Name=Stage,Value=$Environment",
            "--start-time", (Get-StartTime).ToString("o"),
            "--end-time", (Get-EndTime).ToString("o"),
            "--period", "300",
            "--statistics", "Sum",
            "--query", "sum(Datapoints[].Sum)",
            "--output", "text"
        )
        $errors5xx = aws @errorArgs
        
        # Get latency
        $latencyArgs = @(
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/ApiGateway",
            "--metric-name", "Latency",
            "--dimensions", "Name=ApiName,Value=$apiName", "Name=Stage,Value=$Environment",
            "--start-time", (Get-StartTime).ToString("o"),
            "--end-time", (Get-EndTime).ToString("o"),
            "--period", "300",
            "--statistics", "Average",
            "--query", "avg(Datapoints[].Average)",
            "--output", "text"
        )
        $latency = aws @latencyArgs
        
        if ($errors5xx -eq "None" -or $null -eq $errors5xx) { $errors5xx = 0 }
        if ($latency -eq "None" -or $null -eq $latency) { $latency = 0 }
        
        Write-Host "`n-- API: $apiName" -ForegroundColor Cyan
        Write-Host "   5xx Errors: $errors5xx"
        Write-Host "   Avg Latency: $([math]::Round([double]$latency, 2)) ms"
        
        if ($errors5xx -gt 0 -or $latency -gt 3000) {
            Write-Host "----------------------------------------" -ForegroundColor Yellow
        } else {
            Write-Host "----------------------------------------" -ForegroundColor Green
        }
    }
    catch {
        Write-Log "Error checking API: $_" -Level Error
    }
}

# ============================================================================
# Investigation Functions
# ============================================================================

function Get-LambdaLogs {
    param([string]$FunctionName)
    
    Write-Log "Fetching Lambda logs for $FunctionName..." -Level Info
    
    $logGroup = "/aws/lambda/$FunctionName"
    
    try {
        Write-Log "Streaming logs (ERROR level only)..." -Level Info
        
        $logArgs = @(
            "logs", "filter-log-events",
            "--log-group-name", $logGroup,
            "--filter-pattern", "ERROR",
            "--start-time", ([int64](Get-StartTime).ToFileTimeUtc()).ToString(),
            "--output", "json"
        )
        aws @logArgs | ConvertFrom-Json | ForEach-Object {
            foreach ($event in $_.events) {
                Write-Host "`n$($event.timestamp) - $($event.message)" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Log "Error fetching logs: $_" -Level Error
    }
}

function Get-RecentDeployments {
    param([string]$FunctionName)
    
    Write-Log "Checking recent deployments for $FunctionName..." -Level Info
    
    try {
        # Using single quotes for JMESPath to avoid variable interpolation issues
        $query = "Versions[?Version != '\$LATEST'].[Version,LastModified,Description]"
        
        $deployArgs = @(
            "lambda", "list-versions-by-function",
            "--function-name", $FunctionName,
            "--max-items", "5",
            "--query", $query,
            "--output", "json"
        )
        $versions = aws @deployArgs | ConvertFrom-Json
        
        Write-Host "`nRecent versions:" -ForegroundColor Cyan
        foreach ($version in $versions) {
            Write-Host "  Version $($version[0]): $($version[1]) - $($version[2])"
        }
    }
    catch {
        Write-Log "Error fetching versions: $_" -Level Error
    }
}

function Get-CloudTrailEvents {
    Write-Log "Fetching recent CloudTrail events..." -Level Info
    
    try {
        $trailArgs = @(
            "cloudtrail", "lookup-events",
            "--lookup-attributes", "AttributeKey=ResourceType,AttributeValue=AWS::Lambda::Function",
            "--start-time", (Get-StartTime).ToString("o"),
            "--max-items", "10",
            "--query", "Events[].[EventTime,EventName,Username,Resources[0].ResourceName]",
            "--output", "json"
        )
        $events = aws @trailArgs | ConvertFrom-Json
        
        Write-Host "`nRecent Lambda events:" -ForegroundColor Cyan
        foreach ($event in $events) {
            Write-Host "  $($event[0]) - $($event[1]) by $($event[2]) on $($event[3])"
        }
    }
    catch {
        Write-Log "Error fetching CloudTrail events: $_" -Level Error
    }
}

# ============================================================================
# Recovery Functions
# ============================================================================

function Invoke-LambdaRollback {
    param([string]$FunctionName)
    
    Write-Log "Rolling back Lambda function: $FunctionName" -Level Warning
    
    # This would typically involve redeploying with SAM
    Write-Host "`nTo rollback manually, run:" -ForegroundColor Yellow
    Write-Host "  cd api" -ForegroundColor White
    Write-Host "  sam deploy --parameter-overrides Environment=$Environment" -ForegroundColor White
}

function Invoke-DynamoDBRestore {
    param(
        [string]$TableName,
        [string]$RestoreTime
    )
    
    Write-Log "Initiating DynamoDB restore for $TableName to $RestoreTime" -Level Warning
    
    $targetTableName = "$TableName-restored-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-Host "`nThis will create a new table: $targetTableName" -ForegroundColor Yellow
    Write-Host "Command to execute:" -ForegroundColor Cyan
    Write-Host "  aws dynamodb restore-table-to-point-in-time" -ForegroundColor White
    Write-Host "    --source-table-name $TableName" -ForegroundColor White
    Write-Host "    --target-table-name $targetTableName" -ForegroundColor White
    Write-Host "    --restore-date-time $RestoreTime" -ForegroundColor White
    
    $confirm = Read-Host "`nProceed with restore? (yes/no)"
    if ($confirm -eq 'yes') {
        try {
            aws dynamodb restore-table-to-point-in-time `
                --source-table-name $TableName `
                --target-table-name $targetTableName `
                --restore-date-time $RestoreTime
            
            Write-Log "Restore initiated. Monitor progress in AWS Console." -Level Success
        }
        catch {
            Write-Log "Error initiating restore: $_" -Level Error
        }
    } else {
        Write-Log "Restore cancelled" -Level Info
    }
}

# ============================================================================
# Main Logic
# ============================================================================

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "         INCIDENT RESPONSE TOOLKIT - $Project" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

switch ($Action) {
    'detect' {
        Write-Log "Running incident detection..." -Level Info
        
        $hasIncident = $false
        
        # Check alarms
        $alarmsOk = Test-AlarmStatus
        if (-not $alarmsOk) { $hasIncident = $true }
        
        # Check services
        if ($Service -eq 'all' -or $Service -eq 'lambda') {
            Test-LambdaHealth
        }
        
        if ($Service -eq 'all' -or $Service -eq 'dynamodb') {
            Test-DynamoDBHealth
        }
        
        if ($Service -eq 'all' -or $Service -eq 'api') {
            Test-APIHealth
        }
        
        Write-Host "`n"
        if ($hasIncident) {
            Write-Log "WARN: INCIDENTS DETECTED - Review output above" -Level Warning
            Write-Log "Next steps: Run with -Action investigate for details" -Level Info
        } else {
            Write-Log "OK: No active alarms detected." -Level Success
        }
    }
    
    'investigate' {
        Write-Log "Starting investigation..." -Level Info
        
        if ($FunctionName) {
            Get-LambdaLogs -FunctionName $FunctionName
            Get-RecentDeployments -FunctionName $FunctionName
        }
        
        Get-CloudTrailEvents
    }
    
    'rollback' {
        if ($Service -eq 'lambda' -and $FunctionName) {
            Invoke-LambdaRollback -FunctionName $FunctionName
        } elseif ($Service -eq 'api') {
            Write-Log "API rollback via SAM deployment" -Level Info
            Invoke-LambdaRollback -FunctionName "all-functions"
        } else {
            Write-Log "Please specify -Service and -FunctionName" -Level Error
        }
    }
    
    'restore' {
        if ($Service -eq 'dynamodb' -and $TableName -and $RestoreTime) {
            Invoke-DynamoDBRestore -TableName $TableName -RestoreTime $RestoreTime
        } else {
            Write-Log "Please specify -Service dynamodb, -TableName, and -RestoreTime" -Level Error
        }
    }
    
    'health-check' {
        Write-Log "Running comprehensive health check..." -Level Info
        
        Test-AlarmStatus | Out-Null
        Test-LambdaHealth
        Test-DynamoDBHealth
        Test-APIHealth
        
        Write-Log "`nHealth check complete" -Level Success
    }
}

Write-Host "`n========================================================`n" -ForegroundColor Cyan
