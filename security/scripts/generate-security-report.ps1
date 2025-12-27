<#
.SYNOPSIS
    Main Aggregator for Security Reporting using Modular Architecture.
    
.DESCRIPTION
    Orchestrates the generation of individual security module reports and aggregates findings
    into a high-level executive summary.
    
    Architecture:
    1. Secrets Module (secrets.ps1) -> secrets.html + output.json
    2. Dependencies Module (dependencies.ps1) -> output.json (References existing HTML)
    3. SAST Module (sast.ps1) -> sast.html + output.json
    4. IaC Module (iac.ps1) -> iac.html + output.json
    5. VA Module (va.ps1) -> va.html + output.json
    6. Main Script -> security-report.html (Aggregated from output.json files)

.PARAMETER ScanResultsDir
    The directory containing the raw scan results (e.g., .../security/result/2023-10-27).
    If not provided, attempts to find the latest scan directory.
#>

param (
    [string]$ScanResultsDir
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot

# Import Modules
try {
    . "$ScriptRoot\modules\secrets.ps1"
    . "$ScriptRoot\modules\dependencies.ps1"
    . "$ScriptRoot\modules\sast.ps1"
    . "$ScriptRoot\modules\iac.ps1"
    . "$ScriptRoot\modules\va.ps1"
} catch {
    Write-Error "Failed to load reporting modules (secrets, dependencies, sast, iac, va). Ensure 'modules' folder exists."
    exit 1
}

# Auto-detect latest scan if not provided
if (-not $ScanResultsDir) {
    $SecurityRoot = (Get-Item $ScriptRoot).Parent.FullName
    $ResultRoot = Join-Path $SecurityRoot "result"
    if (Test-Path $ResultRoot) {
        $LatestScan = Get-ChildItem $ResultRoot | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($LatestScan) {
            $ScanResultsDir = $LatestScan.FullName
            Write-Host "Auto-detected latest scan: $ScanResultsDir" -ForegroundColor Cyan
        }
    }
}

if (-not $ScanResultsDir -or -not (Test-Path $ScanResultsDir)) {
    Write-Error "Scan results directory not found. Please provide -ScanResultsDir."
    exit 1
}

# Define Paths
$SecretsDir = Join-Path $ScanResultsDir "1.secrets"
$DepsDir    = Join-Path $ScanResultsDir "2.dependencies"
$SastDir    = Join-Path $ScanResultsDir "3.sast"
$IacDir     = Join-Path $ScanResultsDir "4.iac"
$VaDir      = Join-Path $ScanResultsDir "5.va"

$MainReportPath = Join-Path $ScanResultsDir "security-report.html"

# ---------------------------------------------------------
# 1. RUN MODULES
# ---------------------------------------------------------

# Secrets
if (Test-Path $SecretsDir) {
    $SecretsJson = Join-Path $SecretsDir "output.json"
    $SecretsHtml = Join-Path $SecretsDir "secrets.html"
    New-SecretsReport `
        -GitleaksPath (Join-Path $SecretsDir "gitleaks.json") `
        -DetectSecretsPath (Join-Path $SecretsDir "detect-secrets.json") `
        -OutputJsonPath $SecretsJson `
        -OutputHtmlPath $SecretsHtml
}

# Dependencies
if (Test-Path $DepsDir) {
    $DepsJson = Join-Path $DepsDir "output.json"
    $DepsReportHTML = Join-Path $DepsDir "dependency-check-report.html"
    # Find JSON report (sometimes default name varies)
    $DepsReportJSON = Join-Path $DepsDir "dependency-check-report.json"
    New-DependencyReport `
        -DependencyCheckJsonPath $DepsReportJSON `
        -DependencyCheckHtmlPath $DepsReportHTML `
        -OutputJsonPath $DepsJson
}

# SAST
if (Test-Path $SastDir) {
    $SastJson = Join-Path $SastDir "output.json"
    $SastHtml = Join-Path $SastDir "sast.html"
    New-SastReport `
        -SemgrepJsonPath (Join-Path $SastDir "semgrep.json") `
        -OutputJsonPath $SastJson `
        -OutputHtmlPath $SastHtml
}

# IaC
if (Test-Path $IacDir) {
    $IacJson = Join-Path $IacDir "output.json"
    $IacHtml = Join-Path $IacDir "iac.html"
    # Aggregate all potential IaC inputs
    $CheckovFiles = @(
        (Join-Path $IacDir "checkov-infra.json"),
        (Join-Path $IacDir "checkov-api.json")
    )
    $TfsecFiles = @(
        (Join-Path $IacDir "tfsec-infra.json"),
        (Join-Path $IacDir "tfsec-api.json")
    )
    New-IacReport `
        -CheckovFiles $CheckovFiles `
        -TfsecFiles $TfsecFiles `
        -OutputJsonPath $IacJson `
        -OutputHtmlPath $IacHtml
}

# VA (DAST)
if (Test-Path $VaDir) {
    $VaJson = Join-Path $VaDir "output.json"
    $VaHtml = Join-Path $VaDir "va.html"
    $ZapFiles = @(
        (Join-Path $VaDir "zap-frontend.json"),
        (Join-Path $VaDir "zap-api.json"),
        (Join-Path $VaDir "zap-report.json") # Fallback
    )
    # Pass paths for Raw HTML reports if they exist
    New-VaReport `
        -ZapJsonFiles $ZapFiles `
        -OutputJsonPath $VaJson `
        -OutputHtmlPath $VaHtml `
        -ZapFrontendHtml (Join-Path $VaDir "zap-frontend.html") `
        -ZapApiHtml (Join-Path $VaDir "zap-api.html")
}


# ---------------------------------------------------------
# 2. AGGREGATE (Read output.json ONLY)
# ---------------------------------------------------------
Write-Host "`nGenerating Consolidated Report..." -ForegroundColor Cyan

$AggregatedData = @()

# Helper to safely read JSON
function Read-ModuleOutput {
    param($Path)
    if (Test-Path $Path) {
        try {
            return Get-Content $Path -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Failed to read $Path"
            return $null
        }
    }
    return $null
}

# Collect Data
$SecretsData = Read-ModuleOutput (Join-Path $SecretsDir "output.json")
$DepsData    = Read-ModuleOutput (Join-Path $DepsDir "output.json")
$SastData    = Read-ModuleOutput (Join-Path $SastDir "output.json")
$IacData     = Read-ModuleOutput (Join-Path $IacDir "output.json")
$VaData      = Read-ModuleOutput (Join-Path $VaDir "output.json")

if ($SecretsData) { $AggregatedData += $SecretsData }
if ($DepsData)    { $AggregatedData += $DepsData }
if ($SastData)    { $AggregatedData += $SastData }
if ($IacData)     { $AggregatedData += $IacData }
if ($VaData)      { $AggregatedData += $VaData }

# ---------------------------------------------------------
# 3. GENERATE HTML
# ---------------------------------------------------------

$TotalFindings = ($AggregatedData | Measure-Object -Property total_findings -Sum).Sum
$ReportDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$ProjectName = "Security Audit" 

# Calculate Overall Risk / Severity
$TotalCritical = 0; $TotalHigh = 0; $TotalMedium = 0; $TotalLow = 0
foreach ($item in $AggregatedData) {
    if ($item.severity) {
        $TotalCritical += $item.severity.critical
        $TotalHigh     += $item.severity.high
        $TotalMedium   += $item.severity.medium
        $TotalLow      += $item.severity.low
    }
}

$RiskLevel = "LOW"
if ($TotalCritical -gt 0) { $RiskLevel = "CRITICAL" }
elseif ($TotalHigh -gt 0) { $RiskLevel = "HIGH" }
elseif ($TotalMedium -gt 0) { $RiskLevel = "MEDIUM" }

$RiskColor = switch ($RiskLevel) {
    "CRITICAL" { "#c0392b" }
    "HIGH"     { "#e67e22" }
    "MEDIUM"   { "#f1c40f" }
    "LOW"      { "#27ae60" }
}

$Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Consolidated Security Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #f4f6f9; color: #333; margin: 0; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; background: #fff; box-shadow: 0 0 15px rgba(0,0,0,0.1); border-radius: 8px; overflow: hidden; }
        .header { background: #2c3e50; color: #fff; padding: 20px 30px; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .meta { text-align: right; font-size: 0.9em; opacity: 0.9; }
        .exec-brief { padding: 30px; background: #ecf0f1; border-bottom: 1px solid #ddd; }
        .risk-banner { display: inline-block; padding: 8px 16px; border-radius: 4px; color: white; font-weight: bold; background-color: $RiskColor; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px; }
        .metric-card { background: white; padding: 20px; border-radius: 6px; text-align: center; box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
        .metric-val { font-size: 32px; font-weight: bold; color: #2c3e50; }
        .metric-lbl { font-size: 12px; text-transform: uppercase; color: #7f8c8d; }
        
        h2 { border-bottom: 2px solid #3498db; padding-bottom: 10px; color: #2c3e50; margin-top: 40px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 15px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #34495e; color: white; }
        tr:hover { background: #f9f9f9; }
        .btn-link { display: inline-block; padding: 6px 12px; background: #3498db; color: white; text-decoration: none; border-radius: 4px; font-size: 13px; }
        .btn-link:hover { background: #2980b9; }
        
        /* Category specific borders/icons could go here */
        .badge { padding: 3px 6px; border-radius: 3px; font-size: 11px; color: white; font-weight: bold; }
        .bg-crit { background-color: #c0392b; }
        .bg-high { background-color: #e67e22; }
        .bg-med { background-color: #f1c40f; color: #333; }
        .bg-low { background-color: #27ae60; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1>Security Assessment Report</h1>
                <div style="font-size: 14px; margin-top: 5px;">Project: $ProjectName</div>
            </div>
            <div class="meta">
                Date: $ReportDate<br>
                Environment: Checked-in Codebase + Runtime (where applicable)
            </div>
        </div>

        <div class="exec-brief">
            <h2>Executive Brief</h2>
            <div style="margin-bottom: 20px;">
                <strong>Overall Risk Rating:</strong> <span class="risk-banner">$RiskLevel</span>
            </div>
            <p>
                This report consolidates security findings from Secrets, Dependencies, SAST, IaC, and DAST scans.
                A total of <strong>$TotalFindings</strong> issues were identified.
            </p>

            <div class="metrics-grid">
                <div class="metric-card">
                    <div class="metric-val">$TotalCritical</div>
                    <div class="metric-lbl">Critical</div>
                </div>
                <div class="metric-card">
                    <div class="metric-val">$TotalHigh</div>
                    <div class="metric-lbl">High</div>
                </div>
                <div class="metric-card">
                    <div class="metric-val">$TotalMedium</div>
                    <div class="metric-lbl">Medium</div>
                </div>
                <div class="metric-card">
                    <div class="metric-val">$TotalLow</div>
                    <div class="metric-lbl">Low</div>
                </div>
            </div>
        </div>

        <div style="padding: 30px;">
            <h2>Overall Findings Summary</h2>
            <table>
                <thead>
                    <tr>
                        <th>Category</th>
                        <th>Tool</th>
                        <th>Total Findings</th>
                        <th>Severity Breakdown</th>
                        <th>Detailed Report</th>
                    </tr>
                </thead>
                <tbody>
"@

foreach ($row in $AggregatedData) {
    # Relativize the link
    $RelLink = switch ($row.category) {
        "Secrets"      { "1.secrets/" + $row.html_report }
        "Dependencies" { "2.dependencies/" + $row.html_report }
        "SAST"         { "3.sast/" + $row.html_report }
        "IaC"          { "4.iac/" + $row.html_report }
        "DAST"         { "5.va/" + $row.html_report }
        default        { $row.html_report } # Fallback
    }

    $SevSummary = ""
    if ($row.severity.critical -gt 0) { $SevSummary += "<span class='badge bg-crit'>Crit: $($row.severity.critical)</span> " }
    if ($row.severity.high -gt 0)     { $SevSummary += "<span class='badge bg-high'>High: $($row.severity.high)</span> " }
    if ($row.severity.medium -gt 0)   { $SevSummary += "<span class='badge bg-med'>Med: $($row.severity.medium)</span> " }
    if ($row.severity.low -gt 0)      { $SevSummary += "<span class='badge bg-low'>Low: $($row.severity.low)</span>" }
    
    if ($SevSummary -eq "") { $SevSummary = "<span style='color:#ccc'>No Issues</span>" }

    $Html += @"
                    <tr>
                        <td>$($row.category)</td>
                        <td>$($row.tool)</td>
                        <td><strong>$($row.total_findings)</strong></td>
                        <td>$SevSummary</td>
                        <td><a href="$RelLink" class="btn-link" target="_blank">View Details</a></td>
                    </tr>
"@
}

$Html += @"
                </tbody>
            </table>

            <h2>Methodology & Scope</h2>
            <div>
                <p>The security assessment was performed using the following automated tools:</p>
                <ul>
                    <li><strong>Secrets Detection:</strong> Scans for hardcoded credentials (gitleaks, detect-secrets).</li>
                    <li><strong>Dependencies:</strong> Known CVEs in libraries (OWASP Dependency-Check).</li>
                    <li><strong>SAST:</strong> Static Code Analysis (Semgrep).</li>
                    <li><strong>IaC:</strong> Infrastructure Misconfigurations (Checkov, TFSec).</li>
                    <li><strong>DAST:</strong> Runtime Vulnerability Assessment (OWASP ZAP).</li>
                </ul>
            </div>
        </div>
    </div>
</body>
</html>
"@

$Html | Out-File -FilePath $MainReportPath -Encoding utf8
Write-Host "Success! Consolidated report generated at: $MainReportPath" -ForegroundColor Green
