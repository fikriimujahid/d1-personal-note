
function New-SastReport {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SemgrepJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputHtmlPath
    )

    Write-Host "  [SAST] Generating report..." -ForegroundColor Cyan

    $findings = @()
    $counts = @{
        critical = 0
        high = 0
        medium = 0
        low = 0
    }

    if (Test-Path $SemgrepJsonPath) {
        try {
            $json = Get-Content $SemgrepJsonPath -Raw | ConvertFrom-Json
            if ($json.results) {
                foreach ($res in $json.results) {
                    $sevRaw = if ($res.extra -and $res.extra.severity) { $res.extra.severity } else { "INFO" }
                    
                    # Map Semgrep severity to standard
                    $severity = switch ($sevRaw) {
                        "ERROR" { "high" }
                        "WARNING" { "medium" }
                        "INFO" { "low" }
                        default { "low" }
                    }

                    # Semgrep sometimes has metadata about CWE or OWASP in 'extra.metadata'
                    $metadata = ""
                    if ($res.extra -and $res.extra.metadata) {
                        if ($res.extra.metadata.cwe) { $metadata += "CWE: " + ($res.extra.metadata.cwe -join ", ") + "<br>" }
                        if ($res.extra.metadata.owasp) { $metadata += "OWASP: " + ($res.extra.metadata.owasp -join ", ") }
                    }

                    $findings += [PSCustomObject]@{
                        RuleID = $res.check_id
                        File = $res.path
                        Line = if ($res.start -and $res.start.line) { $res.start.line } else { 0 }
                        Severity = $severity
                        Message = if ($res.extra -and $res.extra.message) { $res.extra.message } else { "" }
                        RawSeverity = $sevRaw
                        Metadata = $metadata
                    }

                    $counts[$severity]++
                }
            }
        } catch {
            Write-Warning "[SAST] Failed to parse Semgrep JSON: $_"
        }
    }

    $total = $findings.Count

    # Generate Output.json
    $outputJson = [PSCustomObject]@{
        tool = "Semgrep"
        category = "SAST"
        scan_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        total_findings = $total
        severity = $counts
        html_report = Split-Path $OutputHtmlPath -Leaf
    }

    $outputJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputJsonPath -Encoding utf8

    # Generate SAST HTML
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>SAST Security Report</title>
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
        .high { background-color: #e74c3c; }
        .medium { background-color: #f39c12; }
        .low { background-color: #3498db; }
        
        .empty-state { padding: 20px; text-align: center; color: #7f8c8d; font-style: italic; background: #fff; border: 1px dashed #ddd; }
        .metadata-box { font-size: 0.8em; color: #666; margin-top: 5px; background: #eee; padding: 4px; border-radius: 3px; display: inline-block; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Static Application Security Testing (SAST)</h1>
        <div class="summary">
            <strong>Total Findings:</strong> $total <br>
            <strong>Breakdown:</strong> High: $($counts.high) | Medium: $($counts.medium) | Low: $($counts.low)
        </div>

        <div class="tool-section">
            <h2>Semgrep</h2>
            <div class="description">
                <p><strong>What is Semgrep?</strong></p>
                <p>
                    <a href="https://semgrep.dev/" class="tool-link" target="_blank">Semgrep</a> is a fast, open-source, static analysis tool for finding bugs and enforcing code standards at editor, commit, and CI time.
                    It parses code into an Abstract Syntax Tree (AST) and searches for patterns that match security vulnerabilities, anti-patterns, or custom rules.
                </p>
            </div>

            <table>
                <tr>
                    <th style="width: 10%">Severity</th>
                    <th style="width: 25%">Rule ID</th>
                    <th style="width: 20%">File Location</th>
                    <th style="width: 45%">Message & Metadata</th>
                </tr>
"@

    if ($findings.Count -eq 0) {
        $htmlContent += "</table><div class='empty-state'>No code-level security issues found.</div>"
    } else {
        $sortedFindings = $findings | Sort-Object Severity, RuleID, File
        
        foreach ($f in $sortedFindings) {
            $badgeClass = $f.Severity
            $displaySev = $f.Severity.ToUpper()
            
            $htmlContent += @"
                <tr>
                    <td><span class="badge $badgeClass">$displaySev</span></td>
                    <td>
                        <div><strong>$($f.RuleID)</strong></div>
                    </td>
                    <td>
                        <div>$($f.File)</div>
                        <div style="font-size:0.85em; color:#888;">Line: $($f.Line)</div>
                    </td>
                    <td>
                        <div>$($f.Message)</div>
                        $(if($f.Metadata){"<div class='metadata-box'>$($f.Metadata)</div>"})
                    </td>
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
                <li><strong>Tool Page:</strong> <a href="https://semgrep.dev/" class="tool-link">Semgrep.dev</a></li>
                <li><strong>OWASP Top 10:</strong> <a href="https://owasp.org/www-project-top-ten/" class="tool-link">OWASP Top 10 Project</a></li>
                <li><strong>Remediation:</strong>
                    <ul>
                        <li>Review the finding to confirm it's not a false positive (SAST tools often flag standard patterns).</li>
                        <li>Follow the specific advice in the message (e.g., "Use parameterized queries").</li>
                        <li>For complex logic, rewrite the code segment to avoid the unsafe pattern.</li>
                        <li>You can ignore false positives by adding a comment <code>// nosemgrep</code> on the line preceding the finding.</li>
                    </ul>
                </li>
            </ul>
        </div>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $OutputHtmlPath -Encoding utf8
    Write-Host "  [SAST] Report generated: $OutputHtmlPath" -ForegroundColor Green
}
