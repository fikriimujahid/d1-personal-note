
function New-DependencyReport {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DependencyCheckJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$DependencyCheckHtmlPath, # We use this path to writing our own HTML now

        [Parameter(Mandatory = $true)]
        [string]$OutputJsonPath
    )

    Write-Host "  [Dependencies] Generating report..." -ForegroundColor Cyan

    $counts = @{
        critical = 0
        high = 0
        medium = 0
        low = 0
    }
    $findings = @()

    if (Test-Path $DependencyCheckJsonPath) {
        try {
            $json = Get-Content $DependencyCheckJsonPath -Raw | ConvertFrom-Json
            
            if ($json.dependencies) {
                # dependency-check typically lists dependencies, and inside them, vulnerabilities
                foreach ($dep in $json.dependencies) {
                    if ($dep.vulnerabilities) {
                        foreach ($vuln in $dep.vulnerabilities) {
                            $sev = "low"
                            if ($vuln.severity) {
                                $sev = $vuln.severity.ToLower()
                            } elseif ($vuln.cvssv3 -and $vuln.cvssv3.baseSeverity) {
                                $sev = $vuln.cvssv3.baseSeverity.ToLower()
                            } elseif ($vuln.cvssv2 -and $vuln.cvssv2.severity) {
                                $sev = $vuln.cvssv2.severity.ToLower()
                            }
                            
                            # Normalize severity
                            switch -Regex ($sev) {
                                "critical" { $counts.critical++ }
                                "high"     { $counts.high++ }
                                "medium|moderate" { $counts.medium++ }
                                default    { $counts.low++ }
                            }
                            
                            $cve = if ($vuln.name) { $vuln.name } else { "Unknown CVE" }
                            $desc = if ($vuln.description) { $vuln.description } else { "No description provided" }

                            $findings += [PSCustomObject]@{
                                Dependency = $dep.fileName
                                CVE = $cve
                                Severity = $sev.ToUpper()
                                Description = $desc
                                Path = $dep.filePath
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Warning "[Dependencies] Failed to parse Dependency-Check JSON: $_"
        }
    } else {
        Write-Warning "[Dependencies] Report not found: $DependencyCheckJsonPath"
    }

    $total = $findings.Count

    # Generate Output.json
    $outputJson = [PSCustomObject]@{
        tool = "OWASP Dependency-Check"
        category = "Dependencies"
        scan_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        total_findings = $total
        severity = $counts
        html_report = Split-Path $DependencyCheckHtmlPath -Leaf
    }

    $outputJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputJsonPath -Encoding utf8

    # Generate Custom HTML Report
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dependency Security Report</title>
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
        .MEDIUM, .MODERATE { background-color: #f39c12; }
        .LOW { background-color: #3498db; }
        
        .empty-state { padding: 20px; text-align: center; color: #7f8c8d; font-style: italic; background: #fff; border: 1px dashed #ddd; }
        .vuln-desc { font-size: 0.9em; color: #555; max-height: 100px; overflow-y: auto; display: block; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Dependency Vulnerability Report</h1>
        <div class="summary">
            <strong>Total Vulnerabilities:</strong> $total <br>
            <strong>Breakdown:</strong> Critical: $($counts.critical) | High: $($counts.high) | Medium: $($counts.medium) | Low: $($counts.low)
        </div>

        <div class="tool-section">
            <h2>OWASP Dependency-Check</h2>
            <div class="description">
                <p><strong>What is OWASP Dependency-Check?</strong></p>
                <p>
                    <a href="https://owasp.org/www-project-dependency-check/" class="tool-link" target="_blank">OWASP Dependency-Check</a> is a Software Composition Analysis (SCA) tool that attempts to detect publicly disclosed vulnerabilities contained within a project's dependencies.
                    It does this by determining if there is a Common Platform Enumeration (CPE) identifier for a given dependency. If found, it generates a report linking to the associated CVE entries.
                </p>
            </div>

            <table>
                <tr>
                    <th style="width: 15%">Severity</th>
                    <th style="width: 20%">Dependency</th>
                    <th style="width: 15%">CVE</th>
                    <th style="width: 50%">Description</th>
                </tr>
"@

    if ($findings.Count -eq 0) {
        $htmlContent += "</table><div class='empty-state'>No known vulnerable dependencies found.</div>"
    } else {
        # Sort by severity (Critical -> High -> Medium -> Low)
        $sortedFindings = $findings | Sort-Object @{Expression={
            switch($_.Severity) {
                 "CRITICAL" { 0 }
                 "HIGH" { 1 }
                 "MEDIUM" { 2 }
                 "MODERATE" { 2 }
                 "LOW" { 3 }
                 default { 4 }
            }
        }}

        foreach ($f in $sortedFindings) {
            $htmlContent += @"
                <tr>
                    <td><span class="badge $($f.Severity)">$($f.Severity)</span></td>
                    <td>
                        <div><strong>$($f.Dependency)</strong></div>
                        <div style="font-size:0.8em; color:#7f8c8d">$($f.Path)</div>
                    </td>
                    <td><a href="https://nvd.nist.gov/vuln/detail/$($f.CVE)" target="_blank" class="tool-link">$($f.CVE)</a></td>
                    <td><span class="vuln-desc">$($f.Description)</span></td>
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
                <li><strong>Tool Page:</strong> <a href="https://owasp.org/www-project-dependency-check/" class="tool-link">OWASP Dependency-Check</a></li>
                <li><strong>Vulnerability Database:</strong> <a href="https://nvd.nist.gov/" class="tool-link">NIST NVD</a></li>
                <li><strong>Remediation:</strong>
                    <ul>
                        <li>Update the affected dependency to a patched version.</li>
                        <li>If a direct patch is not available, investigate if the vulnerability is reachable in your specific context (Exploitability Assessment).</li>
                        <li>Temporarily suppress false positives using a suppression XML file if confirmed.</li>
                    </ul>
                </li>
            </ul>
        </div>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $DependencyCheckHtmlPath -Encoding utf8
    Write-Host "  [Dependencies] Report generated: $DependencyCheckHtmlPath" -ForegroundColor Green
}
