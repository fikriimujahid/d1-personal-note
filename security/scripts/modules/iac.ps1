
function New-IacReport {
    param (
        [string[]]$CheckovFiles,
        [string[]]$TfsecFiles,
        [Parameter(Mandatory = $true)]
        [string]$OutputJsonPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputHtmlPath
    )

    Write-Host "  [IaC] Generating report..." -ForegroundColor Cyan

    $findings = @()
    $counts = @{
        critical = 0
        high = 0
        medium = 0
        low = 0
    }

    $processedCheckov = @()
    $processedTfsec = @()

    # 1. Process Checkov Files
    foreach ($path in $CheckovFiles) {
        if ($path -and (Test-Path $path)) {
            try {
                $json = Get-Content $path -Raw | ConvertFrom-Json
                $results = if ($json -is [array]) { $json } else { @($json) }

                foreach ($res in $results) {
                    if ($res.results -and $res.results.failed_checks) {
                        foreach ($check in $res.results.failed_checks) {
                            $sev = if ($check.severity) { $check.severity.ToLower() } else { "medium" }
                            switch ($sev) {
                                "high" { $counts.high++ }
                                "medium" { $counts.medium++ }
                                "low" { $counts.low++ }
                                default { $counts.medium++ }
                            }
                            
                            $item = [PSCustomObject]@{
                                Tool = "Checkov"
                                RuleID = $check.check_id
                                Resource = $check.resource
                                File = $check.file_path
                                Severity = $sev.ToUpper()
                                Description = $check.check_name
                                Link = if ($check.guideline) { $check.guideline } else { "https://www.checkov.io/" }
                            }
                            $findings += $item
                            $processedCheckov += $item
                        }
                    }
                }
            } catch {
                Write-Warning "[IaC] Failed to parse Checkov file $path : $_"
            }
        }
    }

    # 2. Process TFSec Files
    foreach ($path in $TfsecFiles) {
        if ($path -and (Test-Path $path)) {
            try {
                $json = Get-Content $path -Raw | ConvertFrom-Json
                if ($json.results) {
                    foreach ($check in $json.results) {
                        $sev = if ($check.severity) { $check.severity.ToLower() } else { "medium" }
                        switch ($sev) {
                            "critical" { $counts.critical++ }
                            "high"     { $counts.high++ }
                            "medium"   { $counts.medium++ }
                            "low"      { $counts.low++ }
                            default    { $counts.low++ }
                        }

                        $item = [PSCustomObject]@{
                            Tool = "TFSec"
                            RuleID = $check.rule_id
                            Resource = if ($check.resource) { $check.resource } else { "N/A" }
                            File = if ($check.location -and $check.location.filename) { $check.location.filename } else { "N/A" }
                            Severity = $sev.ToUpper()
                            Description = $check.description
                            Link = if ($check.links) { $check.links[0] } else { "https://aquasecurity.github.io/tfsec/" }
                        }
                        $findings += $item
                        $processedTfsec += $item
                    }
                }
            } catch {
                Write-Warning "[IaC] Failed to parse TFSec file $path : $_"
            }
        }
    }

    $total = $findings.Count

    # 3. Generate Output.json
    $outputJson = [PSCustomObject]@{
        tool = "Checkov/TFSec"
        category = "IaC"
        scan_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        total_findings = $total
        severity = $counts
        html_report = Split-Path $OutputHtmlPath -Leaf
    }

    $outputJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputJsonPath -Encoding utf8

    # 4. Generate IaC HTML
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>IaC Security Report</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; padding: 20px; background: #f5f5f5; color: #333; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; margin-top: 0; }
        h2 { color: #2c3e50; margin-top: 40px; border-bottom: 1px solid #eee; padding-bottom: 5px; }
        .summary { margin-bottom: 30px; padding: 15px; background: #ecf0f1; border-radius: 5px; }
        
        .tool-section { margin-top: 30px; }
        .description { background-color: #f9f9f9; padding: 15px; border-left: 4px solid #3498db; margin-bottom: 20px; }
        .description p { margin: 5px 0; line-height: 1.5; }
        .tool-link { font-weight: bold; color: #3498db; text-decoration: none; }
        .tool-link:hover { text-decoration: underline; }

        table { width: 100%; border-collapse: collapse; margin-top: 10px; table-layout: fixed; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; word-wrap: break-word; }
        th { background-color: #34495e; color: white; }
        tr:hover { background-color: #f1f1f1; }
        
        .badge { padding: 4px 8px; border-radius: 4px; color: white; font-size: 0.85em; font-weight: bold; }
        .CRITICAL { background-color: #c0392b; }
        .HIGH { background-color: #e74c3c; }
        .MEDIUM { background-color: #f39c12; }
        .LOW { background-color: #3498db; }
        
        .empty-state { padding: 20px; text-align: center; color: #7f8c8d; font-style: italic; background: #fff; border: 1px dashed #ddd; }
        .res-name { font-weight: bold; color: #444; }
        .file-path { font-size: 0.85em; color: #888; margin-top: 2px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Infrastructure as Code (IaC) Security</h1>
        <div class="summary">
            <strong>Total Misconfigurations:</strong> $total <br>
            <strong>Breakdown:</strong> Critical: $($counts.critical) | High: $($counts.high) | Medium: $($counts.medium) | Low: $($counts.low)
        </div>

        <div class="tool-section">
            <h2>1. Checkov</h2>
            <div class="description">
                <p><strong>What is Checkov?</strong></p>
                <p>
                    <a href="https://www.checkov.io/" class="tool-link" target="_blank">Checkov</a> is a static code analysis tool for infrastructure-as-code.
                    It scans cloud infrastructure provisioned using Terraform, CloudFormation, Kubernetes, Serverless, and ARM Templates and detects security and compliance misconfigurations.
                </p>
            </div>
            <table>
                <tr>
                    <th style="width: 10%">Severity</th>
                    <th style="width: 15%">Rule ID</th>
                    <th style="width: 30%">Resource / File</th>
                    <th style="width: 45%">Description</th>
                </tr>
"@

    if ($processedCheckov.Count -eq 0) {
        $htmlContent += "</table><div class='empty-state'>No Checkov findings.</div>"
    } else {
        foreach ($f in ($processedCheckov | Sort-Object Severity)) {
            $htmlContent += @"
                <tr>
                    <td><span class="badge $($f.Severity)">$($f.Severity)</span></td>
                    <td><a href="$($f.Link)" target="_blank" class="tool-link">$($f.RuleID)</a></td>
                    <td>
                        <div class="res-name">$($f.Resource)</div>
                        <div class="file-path">$($f.File)</div>
                    </td>
                    <td>$($f.Description)</td>
                </tr>
"@
        }
        $htmlContent += "</table>"
    }

    $htmlContent += @"
        </div>

        <div class="tool-section">
            <h2>2. TFSec</h2>
            <div class="description">
                <p><strong>What is TFSec?</strong></p>
                <p>
                    <a href="https://aquasecurity.github.io/tfsec/" class="tool-link" target="_blank">TFSec</a> uses static analysis of your terraform code to spot potential security issues.
                    It checks for things like sensitive data inclusion, lack of encryption, open security groups, and more.
                </p>
            </div>
            <table>
                <tr>
                    <th style="width: 10%">Severity</th>
                    <th style="width: 15%">Rule ID</th>
                    <th style="width: 30%">Resource / File</th>
                    <th style="width: 45%">Description</th>
                </tr>
"@
    
    if ($processedTfsec.Count -eq 0) {
        $htmlContent += "</table><div class='empty-state'>No TFSec findings.</div>"
    } else {
        foreach ($f in ($processedTfsec | Sort-Object Severity)) {
            $htmlContent += @"
                <tr>
                    <td><span class="badge $($f.Severity)">$($f.Severity)</span></td>
                    <td><a href="$($f.Link)" target="_blank" class="tool-link">$($f.RuleID)</a></td>
                    <td>
                        <div class="res-name">$($f.Resource)</div>
                        <div class="file-path">$($f.File)</div>
                    </td>
                    <td>$($f.Description)</td>
                </tr>
"@
        }
        $htmlContent += "</table>"
    }

    $htmlContent += @"
        </div>

        <div class="tool-section" style="margin-top: 50px; border-top: 2px solid #eee; padding-top: 20px;">
            <h2>Remediation</h2>
            <ul>
                <li><strong>Checkov Rules:</strong> <a href="https://www.checkov.io/5.Policy%20Index/all.html" class="tool-link">Policy Index</a></li>
                <li><strong>TFSec Rules:</strong> <a href="https://aquasecurity.github.io/tfsec/v1.28.1/checks/aws/" class="tool-link">AWS Checks</a></li>
                <li><strong>General Advice:</strong> 
                    <ul>
                        <li>Apply least privilege to IAM policies.</li>
                        <li>Ensure encryption at rest and in transit is enabled for all data stores.</li>
                        <li>Restrict security groups to minimum required ports and ranges.</li>
                    </ul>
                </li>
            </ul>
        </div>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $OutputHtmlPath -Encoding utf8
    Write-Host "  [IaC] Report generated: $OutputHtmlPath" -ForegroundColor Green
}
