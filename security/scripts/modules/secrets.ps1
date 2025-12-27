
function New-SecretsReport {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GitleaksPath,

        [Parameter(Mandatory = $true)]
        [string]$DetectSecretsPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputHtmlPath
    )

    Write-Host "  [Secrets] Generating report..." -ForegroundColor Cyan

    # 1. Parse Gitleaks
    $gitleaksFindings = @()
    if (Test-Path $GitleaksPath) {
        try {
            $json = Get-Content $GitleaksPath -Raw | ConvertFrom-Json
            if ($json) { $gitleaksFindings = @($json) }
        } catch {
            Write-Warning "[Secrets] Failed to parse Gitleaks report: $_"
        }
    }

    # Normalize Gitleaks findings
    $normalizedGitleaks = $gitleaksFindings | ForEach-Object {
        [PSCustomObject]@{
            File = if ($_.File) { $_.File } elseif ($_.file) { $_.file } else { "Unknown" }
            Line = if ($_.StartLine) { $_.StartLine } elseif ($_.Line) { $_.Line } else { 0 }
            RuleID = if ($_.RuleID) { $_.RuleID } elseif ($_.Rule) { $_.Rule } else { "Unknown" }
            Description = if ($_.Description) { $_.Description } else { "Potential secret detected (gitleaks)" }
            Tool = "gitleaks"
            Severity = "CRITICAL"
        }
    }

    # 2. Parse Detect-Secrets
    $dsFindings = @()
    if (Test-Path $DetectSecretsPath) {
        try {
            $json = Get-Content $DetectSecretsPath -Raw | ConvertFrom-Json
            # detect-secrets 'results' is a hash where key=filename, value=list of findings
            if ($json.results) {
                foreach ($file in $json.results.PSObject.Properties.Name) {
                    foreach ($finding in $json.results.$file) {
                        # Standardize object
                        $dsFindings += [PSCustomObject]@{
                            File = $file
                            Line = $finding.line_number
                            RuleID = $finding.type
                            Description = "Potential secret detected (detect-secrets)"
                            Tool = "detect-secrets"
                            Severity = "CRITICAL"
                        }
                    }
                }
            }
        } catch {
            Write-Warning "[Secrets] Failed to parse Detect-Secrets report: $_"
        }
    }

    $allFindings = $normalizedGitleaks + $dsFindings
    $totalCount = $allFindings.Count

    # 3. Generate Output.json
    $outputJson = [PSCustomObject]@{
        tool = "SecretsScanner"
        category = "Secrets"
        scan_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        total_findings = $totalCount
        severity = @{
            critical = $totalCount # All secrets are critical
            high = 0
            medium = 0
            low = 0
        }
        html_report = Split-Path $OutputHtmlPath -Leaf
    }

    $outputJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputJsonPath -Encoding utf8

    # 4. Generate Secrets HTML with improved layout
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Secrets Scan Report</title>
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

        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #34495e; color: white; }
        tr:hover { background-color: #f1f1f1; }
        
        .badge { padding: 4px 8px; border-radius: 4px; color: white; font-size: 0.85em; font-weight: bold; }
        .critical { background-color: #c0392b; }
        .empty-state { padding: 20px; text-align: center; color: #7f8c8d; font-style: italic; background: #fff; border: 1px dashed #ddd; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Secrets & Credentials Report</h1>
        <div class="summary">
            <strong>Total Findings:</strong> $totalCount <br>
            <strong>Status:</strong> $(if($totalCount -eq 0){"<span style='color:green'>PASS</span>"}else{"<span style='color:red; font-weight:bold'>FAIL - Immediate Action Required</span>"})
        </div>

        <div class="tool-section">
            <h2>1. Detect-Secrets</h2>
            <div class="description">
                <p><strong>What is detect-secrets?</strong></p>
                <p>
                    <a href="https://github.com/Yelp/detect-secrets" class="tool-link" target="_blank">detect-secrets</a> is an enterprise-friendly tool for preventing secrets from entering your code base. 
                    It focuses on detecting secrets in code files by identifying high entropy strings and common secret patterns (e.g. AWS keys, Private Keys).
                    It is designed to be used as a pre-commit hook to catch secrets before they are committed.
                </p>
            </div>

            <table>
                <tr>
                    <th style="width: 30%">File</th>
                    <th style="width: 10%">Line</th>
                    <th style="width: 30%">Type</th>
                    <th style="width: 30%">Details</th>
                </tr>
"@

    if ($dsFindings.Count -eq 0) {
        $htmlContent += "</table><div class='empty-state'>No secrets detected by detect-secrets.</div>"
    } else {
        foreach ($f in $dsFindings) {
            $htmlContent += @"
                <tr>
                    <td>$($f.File)</td>
                    <td>$($f.Line)</td>
                    <td>$($f.RuleID)</td>
                    <td><span class="badge critical">CRITICAL</span> Potential Secret</td>
                </tr>
"@
        }
        $htmlContent += "</table>"
    }

    $htmlContent += @"
        </div>

        <div class="tool-section">
            <h2>2. Gitleaks</h2>
            <div class="description">
                <p><strong>What is Gitleaks?</strong></p>
                <p>
                    <a href="https://github.com/gitleaks/gitleaks" class="tool-link" target="_blank">Gitleaks</a> is a fast, light-weight, portable, and open-source SAST tool for detecting hardcoded secrets like passwords, API keys, and tokens in git repos, files, and directories.
                    It uses regex rules to identify specific patterns of known secrets (like Facebook tokens, AWS keys, etc.).
                </p>
            </div>

            <table>
                <tr>
                    <th style="width: 30%">File</th>
                    <th style="width: 10%">Line</th>
                    <th style="width: 30%">Rule</th>
                    <th style="width: 30%">Description</th>
                </tr>
"@

    if ($normalizedGitleaks.Count -eq 0) {
        $htmlContent += "</table><div class='empty-state'>No secrets detected by Gitleaks.</div>"
    } else {
        foreach ($f in $normalizedGitleaks) {
            $htmlContent += @"
                <tr>
                    <td>$($f.File)</td>
                    <td>$($f.Line)</td>
                    <td>$($f.RuleID)</td>
                    <td><span class="badge critical">CRITICAL</span> $($f.Description)</td>
                </tr>
"@
        }
        $htmlContent += "</table>"
    }

    $htmlContent += @"
        </div>

        <div class="tool-section" style="margin-top: 50px; border-top: 2px solid #eee; padding-top: 20px;">
            <h2>References & Remediation</h2>
            <ul>
                <li><strong>Detect Secrets:</strong> <a href="https://github.com/Yelp/detect-secrets" class="tool-link">GitHub Repository</a></li>
                <li><strong>Gitleaks:</strong> <a href="https://github.com/gitleaks/gitleaks" class="tool-link">GitHub Repository</a></li>
                <li><strong>Remediation:</strong>
                    <ul>
                        <li>Rotate any exposed credentials immediately.</li>
                        <li>Remove secrets from git history using <a href="https://rtyley.github.io/bfg-repo-cleaner/" class="tool-link">BFG Repo-Cleaner</a> or <code>git filter-repo</code>.</li>
                        <li>Use environment variables or a secrets manager (AWS Secrets Manager, Vault) instead of hardcoding.</li>
                    </ul>
                </li>
            </ul>
        </div>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $OutputHtmlPath -Encoding utf8
    Write-Host "  [Secrets] Report generated: $OutputHtmlPath" -ForegroundColor Green
}
