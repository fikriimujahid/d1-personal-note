
function New-VaReport {
    param (
        [string[]]$ZapJsonFiles,
        [string]$ZapFrontendHtml, # Optional path to raw frontend report
        [string]$ZapApiHtml,      # Optional path to raw api report
        [Parameter(Mandatory = $true)]
        [string]$OutputJsonPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputHtmlPath
    )

    Write-Host "  [VA] Generating report..." -ForegroundColor Cyan

    $counts = @{
        critical = 0
        high = 0
        medium = 0
        low = 0
    }

    $frontendFindings = @()
    $apiFindings = @()
    $otherFindings = @() # For legacy/generic filenames

    # Helper function to process alerts from a ZAP JSON
    function Process-Zap-Json {
        param($path)
        $fileFindings = @()
        
        if ($path -and (Test-Path $path)) {
            try {
                $json = Get-Content $path -Raw | ConvertFrom-Json
                
                # ZAP output structure: { site: [ { alerts: [ ... ] } ] }
                if ($json.site) {
                    foreach ($site in $json.site) {
                        if ($site.alerts) {
                            foreach ($alert in $site.alerts) {
                                # ZAP risk map: "High", "Medium", "Low", "Informational"
                                $risk = "low"
                                if ($alert.riskdesc) {
                                    $desc = $alert.riskdesc.Split('(')[0].Trim().ToLower()
                                    $risk = $desc
                                } elseif ($alert.riskcode) {
                                    $risk = switch ($alert.riskcode) {
                                        3 { "high" }
                                        2 { "medium" }
                                        1 { "low" }
                                        default { "low" }
                                    }
                                }

                                # Increment Global Counts
                                switch ($risk) {
                                    "high"   { $counts.high++ }
                                    "medium" { $counts.medium++ }
                                    "low"    { $counts.low++ }
                                    "informational" { $counts.low++ } 
                                    default  { $counts.low++ }
                                }

                                # Instances
                                $urls = @()
                                if ($alert.instances) {
                                    foreach ($inst in $alert.instances) {
                                        $method = if ($inst.method) { $inst.method } else { "GET" }
                                        $urls += "$method $($inst.uri)"
                                    }
                                }
                                $urlStr = $urls -join "<br>"

                                $fileFindings += [PSCustomObject]@{
                                    Alert = $alert.name
                                    Risk = $risk.ToUpper()
                                    Description = $alert.desc
                                    Solution = $alert.solution
                                    Urls = $urlStr
                                    Reference = $alert.reference
                                    CWEID = $alert.cweid
                                    WASCID = $alert.wascid
                                }
                            }
                        }
                    }
                }
            } catch {
                Write-Warning "[VA] Failed to parse ZAP file $path : $_"
            }
        }
        return $fileFindings
    }

    # Categorize and process files
    foreach ($file in $ZapJsonFiles) {
        $findings = Process-Zap-Json -path $file
        if ($findings.Count -gt 0) {
           if ($file -match "frontend") {
               $frontendFindings += $findings
           } elseif ($file -match "api") {
               $apiFindings += $findings
           } else {
               $otherFindings += $findings
           }
        }
    }

    $total = $frontendFindings.Count + $apiFindings.Count + $otherFindings.Count

    # Generate Output.json
    $outputJson = [PSCustomObject]@{
        tool = "OWASP ZAP"
        category = "DAST"
        scan_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        total_findings = $total
        severity = $counts
        html_report = Split-Path $OutputHtmlPath -Leaf
    }

    $outputJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputJsonPath -Encoding utf8

    # Generate VA HTML
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>DAST Security Report</title>
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
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; word-wrap: break-word; vertical-align: top; }
        th { background-color: #34495e; color: white; }
        tr:hover { background-color: #f1f1f1; }
        
        .badge { padding: 4px 8px; border-radius: 4px; color: white; font-size: 0.85em; font-weight: bold; }
        .HIGH { background-color: #e74c3c; }
        .MEDIUM { background-color: #f39c12; }
        .LOW { background-color: #3498db; }
        .INFORMATIONAL { background-color: #95a5a6; }
        
        .empty-state { padding: 20px; text-align: center; color: #7f8c8d; font-style: italic; background: #fff; border: 1px dashed #ddd; }
        .url-box { font-family: monospace; font-size: 0.85em; background: #f8f9fa; padding: 5px; border: 1px solid #eee; margin-top: 5px; max-height: 100px; overflow-y: auto; }
        .solution-box { margin-top: 10px; font-size: 0.9em; border-left: 3px solid #27ae60; padding-left: 10px; color: #555; }
        .raw-report-link { display: inline-block; padding: 5px 10px; margin-left: 10px; background: #eee; border-radius: 4px; font-size: 0.9em; text-decoration: none; color: #333; border: 1px solid #ddd; }
        .raw-report-link:hover { background: #e0e0e0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Vulnerability Assessment (DAST)</h1>
        <div class="summary">
            <strong>Total Alerts:</strong> $total <br>
            <strong>Breakdown:</strong> High: $($counts.high) | Medium: $($counts.medium) | Low/Info: $($counts.low)
        </div>

        <div class="tool-section">
            <h2>OWASP ZAP Scans</h2>
            <div class="description">
                <p><strong>What is OWASP ZAP?</strong></p>
                <p>
                    <a href="https://www.zaproxy.org/" class="tool-link" target="_blank">OWASP Zed Attack Proxy (ZAP)</a> is a Dynamic Application Security Testing (DAST) tool. 
                    It actively interacts with your running application (both Frontend and API) to find security vulnerabilities such as Cross-Site Scripting (XSS), SQL Injection, and security misconfigurations.
                </p>
                <p>This report consolidates findings from:</p>
                <ul>
                    <li><strong>Frontend Scan:</strong> Analysis of the Single Page Application (SPA) using AJAXSpider.</li>
                    <li><strong>API Scan:</strong> Analysis of the Backend API using OpenAPI definitions.</li>
                </ul>
            </div>
        </div>

        <!-- Frontend Findings -->
        <div class="tool-section">
            <h3 style="display:flex; align-items:center;">
                Frontend (SPA) Findings 
"@

    if ($ZapFrontendHtml -and (Test-Path $ZapFrontendHtml)) {
        $feLink = Split-Path $ZapFrontendHtml -Leaf
        $htmlContent += "<a href='$feLink' target='_blank' class='raw-report-link'>View Full ZAP Report</a>"
    }

    $htmlContent += @"
            </h3>
"@

    if ($frontendFindings.Count -eq 0) {
        $htmlContent += "<div class='empty-state'>No issues found in Frontend Scan (or scan not run).</div>"
    } else {
        $htmlContent += @"
            <table>
                <tr>
                    <th style="width: 10%">Risk</th>
                    <th style="width: 20%">Alert</th>
                    <th style="width: 40%">Description & Solution</th>
                    <th style="width: 30%">Affected URLs</th>
                </tr>
"@
        foreach ($f in ($frontendFindings | Sort-Object Risk -Descending)) {
            $htmlContent += @"
                <tr>
                    <td><span class="badge $($f.Risk)">$($f.Risk)</span></td>
                    <td><strong>$($f.Alert)</strong></td>
                    <td>
                        <div style="font-size:0.9em">$($f.Description)</div>
                        <div class="solution-box"><strong>Solution:</strong> $($f.Solution)</div>
                    </td>
                    <td><div class="url-box">$($f.Urls)</div></td>
                </tr>
"@
        }
        $htmlContent += "</table>"
    }

    # API Findings
    $htmlContent += @"
        </div>
        <div class="tool-section">
            <h3 style="display:flex; align-items:center;">
                Backend (API) Findings
"@
    
    if ($ZapApiHtml -and (Test-Path $ZapApiHtml)) {
        $apiLink = Split-Path $ZapApiHtml -Leaf
        $htmlContent += "<a href='$apiLink' target='_blank' class='raw-report-link'>View Full ZAP Report</a>"
    }

    $htmlContent += "</h3>"

    if ($apiFindings.Count -eq 0) {
        $htmlContent += "<div class='empty-state'>No issues found in API Scan (or scan not run).</div>"
    } else {
        $htmlContent += @"
            <table>
                <tr>
                    <th style="width: 10%">Risk</th>
                    <th style="width: 20%">Alert</th>
                    <th style="width: 40%">Description & Solution</th>
                    <th style="width: 30%">Affected URLs</th>
                </tr>
"@
        foreach ($f in ($apiFindings | Sort-Object Risk -Descending)) {
            $htmlContent += @"
                <tr>
                    <td><span class="badge $($f.Risk)">$($f.Risk)</span></td>
                    <td><strong>$($f.Alert)</strong></td>
                    <td>
                        <div style="font-size:0.9em">$($f.Description)</div>
                        <div class="solution-box"><strong>Solution:</strong> $($f.Solution)</div>
                    </td>
                    <td><div class="url-box">$($f.Urls)</div></td>
                </tr>
"@
        }
        $htmlContent += "</table>"
    }

    $htmlContent += @"
        </div>

        <div class="tool-section" style="margin-top: 50px; border-top: 2px solid #eee; padding-top: 20px;">
            <h2>References</h2>
            <ul>
                <li><strong>OWASP ZAP:</strong> <a href="https://www.zaproxy.org/" class="tool-link">Official Site</a></li>
                <li><strong>Common Weakness Enumeration (CWE):</strong> <a href="https://cwe.mitre.org/" class="tool-link">MITRE CWE</a></li>
                <li><strong>Remediation:</strong>
                    <ul>
                        <li>Implement missing security headers (CSP, HSTS, X-Frame-Options).</li>
                        <li>Ensure proper input validation and output encoding to prevent XSS.</li>
                        <li>Review API authentication and authorization controls.</li>
                    </ul>
                </li>
            </ul>
        </div>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $OutputHtmlPath -Encoding utf8
    Write-Host "  [VA] Report generated: $OutputHtmlPath" -ForegroundColor Green
}
