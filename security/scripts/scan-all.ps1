<#
==========================================================
Unified Security Scan Script (Compliance-Aligned)
==========================================================

This script supports the following security testing activities:

✔ Vulnerability Management System (VMS)
✔ OWASP Dependency Checker
✔ Source Code Review (SCR - automated)
✔ Infrastructure as Code (IaC) scanning
✔ Vulnerability Assessment (VA / DAST)

NOT included:
❌ Penetration Test (PT) – External / Human-led

This script is designed to be run by:
- Security engineers
- Compliance teams
- CI/CD pipelines

WITHOUT interrupting development workflows.

----------------------------------------------------------
USAGE EXAMPLES

Monthly / Weekly (VMS):
  .\scan-all.ps1 -Mode monthly

Source Code Review (major changes):
  .\scan-all.ps1 -Mode on-change

Vulnerability Assessment (DAST) - Unauthenticated:
  .\scan-all.ps1 -Mode va -TargetUrl "URL"

Vulnerability Assessment (DAST) - Authenticated:
  .\scan-all.ps1 -Mode va -TargetUrl "URL" -TargetApiUrl "API_URL" -AuthUser "USER" -AuthPass "PASS" -CognitoClientId "CLIENT_ID"

Vulnerability Assessment (DAST) - With URL Seed File:
  .\scan-all.ps1 -Mode va -TargetUrl "URL" -AuthUser "USER" -AuthPass "PASS" -CognitoClientId "CLIENT_ID" -UrlSeedFile ".\security\scripts\zap-urls.txt"

All Checks (Default):
  .\scan-all.ps1

==========================================================
#>

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("monthly", "on-change", "va", "all")]
    [string]$Mode = "all",

    # Required ONLY for VA (DAST)
    [string]$TargetUrl,
    
    # Optional Auth Parameters (for ZAP)
    [string]$AuthLoginUrl,      # URL for login (API endpoint or Cognito IDP URL)
    [string]$AuthUser,          # Username
    [string]$AuthPass,          # Password
    [string]$CognitoClientId,   # Optional: If using direct Cognito Auth
    
    # Optional: API Target URL for Backend Scanning
    [string]$TargetApiUrl,

    # Optional: URL seed file for comprehensive scanning
    [string]$UrlSeedFile        # Path to file containing URLs to scan (one per line)
)

$ErrorActionPreference = "Continue"
$DATE = Get-Date -Format "dd-MM-yyyy"
$env:PYTHONUTF8 = "1"

# Fix: Report path relative to project root
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$BASE = Join-Path $ProjectRoot "security\result\$DATE"

Write-Host "Security Scan Mode: $Mode" -ForegroundColor Cyan
Write-Host "Date: $DATE" -ForegroundColor Cyan
Write-Host "Report Path: $BASE" -ForegroundColor Cyan

# ----------------------------------------------------------
# Directory Structure (Audit-Friendly)
# ----------------------------------------------------------
$dirs = @(
    "$BASE/1.secrets",
    "$BASE/2.dependencies",
    "$BASE/3.sast",
    "$BASE/4.iac",
    "$BASE/5.va"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

function Run-ScanTool {
    param (
        [string]$Name,
        [scriptblock]$CommandBlock,
        [string]$Description
    )
    Write-Host "Checking tool: $Name..." -NoNewline
    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        Write-Host " [OK]" -ForegroundColor Green
        Write-Host "Running $Description ($Name)..." -ForegroundColor Yellow
        try {
            & $CommandBlock
        } catch {
            Write-Error "Failed to execute $Name : $_"
        }
    } else {
        if ($Name -eq "docker") {
             # Special case for docker fallback messaging
             Write-Host " [OK]" -ForegroundColor Green
             Write-Host "Running $Description ($Name)..." -ForegroundColor Yellow
             try {
                & $CommandBlock
             } catch {
                Write-Error "Failed to execute $Name : $_"
             }
        } else {
            Write-Host " [MISSING]" -ForegroundColor Red
            Write-Warning "Tool '$Name' is not installed or not in PATH. Skipping scan."
        }
    }
}

# ==========================================================
# 1. Secrets Scanning (Continuous / VMS)
# ==========================================================
if ($Mode -in @("monthly", "on-change", "all")) {
    Run-ScanTool -Name "detect-secrets" -Description "Secrets Scanning" -CommandBlock {

        $baselinePath = Join-Path $ProjectRoot "security\.secrets.baseline"
        $excludePattern = "(node_modules|\.git|\.aws-sam|dist|build|coverage|\.terraform|dependency-check-data|result)"

        Push-Location $ProjectRoot
        try {
            Write-Host "  Running detect-secrets scan..." -ForegroundColor Gray
            if (-not (Test-Path $baselinePath)) {
                Write-Host "  No baseline found. Creating initial baseline..." -ForegroundColor Yellow
                $tempScan = Join-Path $env:TEMP "detect-secrets-scan-$(Get-Date -Format 'yyyyMMddHHmmss').json"
                detect-secrets scan `
                    --all-files `
                    --exclude-files "$excludePattern" `
                    | Out-File -FilePath $tempScan -Encoding utf8
                
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                $content = [System.IO.File]::ReadAllText($tempScan, $utf8NoBom)
                [System.IO.File]::WriteAllText($baselinePath, $content, $utf8NoBom)
                Remove-Item $tempScan -ErrorAction SilentlyContinue
                Write-Host "  Baseline created. Run audit before committing:" -ForegroundColor Cyan
                Write-Host "    detect-secrets audit security\.secrets.baseline" -ForegroundColor Cyan
                return
            }
            detect-secrets scan `
                --all-files `
                --exclude-files "$excludePattern" `
                --baseline $baselinePath

            if ($LASTEXITCODE -ne 0) {
                Write-Host "  New secrets detected!" -ForegroundColor Red
                Write-Host "  Run audit to review them:" -ForegroundColor Yellow
                Write-Host "    detect-secrets audit .secrets.baseline" -ForegroundColor Yellow
            }
            Write-Host "  No new secrets found" -ForegroundColor Green
            Copy-Item $baselinePath "$BASE/1.secrets/detect-secrets.json" -Force
        } finally {
            Pop-Location
        }
    }

    Run-ScanTool -Name "gitleaks" -Description "Gitleaks" -CommandBlock {
        $reportPath = "$BASE/1.secrets/gitleaks.json"
        gitleaks detect --source $ProjectRoot --no-git --report-format json --report-path $reportPath
    }
}

# ==========================================================
# 2. Dependency Scanning (Monthly Requirement)
# ==========================================================
if ($Mode -in @("monthly", "all")) {
    $depCheckOut = "$BASE/2.dependencies"
    
    if (Get-Command "dependency-check" -ErrorAction SilentlyContinue) {
        Run-ScanTool -Name "dependency-check" -Description "OWASP Dependency-Check (Local)" -CommandBlock {
            dependency-check --scan . --format JSON --out $depCheckOut --disableAssembly
        }
    } 
    elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
         $CurrentDir = $ProjectRoot
         $DockerSrc = $CurrentDir.Replace('\', '/')
         $RelReportPath = $BASE.Replace($CurrentDir, "").Trim('\').Replace('\', '/')
         $ContainerOut = "/src/$RelReportPath/2.dependencies"
         $DataDir = Join-Path $ProjectRoot "security\dependency-check-data"
         if (-not (Test-Path $DataDir)) {
            New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
         }
         $DockerData = $DataDir.Replace('\', '/')

         Run-ScanTool -Name "docker" -Description "OWASP Dependency-Check (Docker)" -CommandBlock {
            Write-Host "Using Docker container: owasp/dependency-check" -ForegroundColor Gray
            $DockerReport = "$BASE/2.dependencies".Replace('\', '/')
            docker run --rm -t --user 0 --volume "${DockerSrc}:/src:ro" --volume "${DockerData}:/usr/share/dependency-check/data" --volume "${DockerReport}:/report" owasp/dependency-check --scan /src -f JSON -f HTML -f SARIF --out /report --project "project-dependency-scan" --disableAssembly --exclude "**/node_modules/**" --exclude "**/.git/**" --exclude "**/dist/**"
         }
    }
}

# ==========================================================
# 3. Source Code Review – Automated (SAST)
# ==========================================================
if ($Mode -in @("monthly", "on-change", "all")) {
    Run-ScanTool -Name "semgrep" -Description "Semgrep SAST" -CommandBlock {
        $env:PYTHONIOENCODING = "utf-8"
        $env:PYTHONUTF8 = "1"
        semgrep scan $ProjectRoot `
        --config p/ci `
        --config p/security-audit `
        --exclude security `
        --exclude node_modules `
        --json `
        --output "$BASE/3.sast/semgrep.json"
    }
}

# ==========================================================
# 4. Infrastructure as Code (Monthly)
# ==========================================================
if ($Mode -in @("monthly", "all")) {
    Run-ScanTool -Name "checkov" -Description "Checkov IaC (Infra)" -CommandBlock {
        $terraformPath = Join-Path $ProjectRoot "infra\terraform"
        checkov -d $terraformPath --output json | Out-File -FilePath "$BASE/4.iac/checkov-infra.json" -Encoding utf8
    }
    Run-ScanTool -Name "checkov" -Description "Checkov IaC (API)" -CommandBlock {
        $apiPath = Join-Path $ProjectRoot "api"
        checkov -d $apiPath --output json | Out-File -FilePath "$BASE/4.iac/checkov-api.json" -Encoding utf8
    }
    Run-ScanTool -Name "tfsec" -Description "tfsec IaC (Infra)" -CommandBlock {
        $terraformPath = Join-Path $ProjectRoot "infra\terraform"
        tfsec $terraformPath --format json | Out-File -FilePath "$BASE/4.iac/tfsec-infra.json" -Encoding utf8
    }
    Run-ScanTool -Name "tfsec" -Description "tfsec IaC (API)" -CommandBlock {
        $apiPath = Join-Path $ProjectRoot "api"
        tfsec $apiPath --format json | Out-File -FilePath "$BASE/4.iac/tfsec-api.json" -Encoding utf8
    }
}

# ==========================================================
# 5. Vulnerability Assessment (VA / DAST)
# ==========================================================
if ($Mode -eq "va") {

    if (-not $TargetUrl -and -not $TargetApiUrl) {
        Write-Error "Either TargetUrl (for Frontend) or TargetApiUrl (for API) is required when Mode=va"
        exit 1
    }

    Write-Host "Vulnerability Assessment (OWASP ZAP)" -ForegroundColor Yellow
    
    if (Get-Command "docker" -ErrorAction SilentlyContinue) {
        
        $zapReportDir = "$BASE/5.va"
        $scriptsDir = Join-Path $ProjectRoot "security\scripts"
        
        # Normalize paths
        $dockerVolReport = $zapReportDir.Replace('\', '/')
        $dockerVolScripts = $scriptsDir.Replace('\', '/')

        # Common Env Vars for Auth
        $envArgs = @()
        if ($AuthUser) { $envArgs += "-e", "ZAP_AUTH_USER=$AuthUser" }
        if ($AuthPass) { $envArgs += "-e", "ZAP_AUTH_PASS=$AuthPass" }
        if ($AuthLoginUrl) { $envArgs += "-e", "ZAP_AUTH_LOGIN_URL=$AuthLoginUrl" }
        if ($CognitoClientId) { $envArgs += "-e", "ZAP_COGNITO_CLIENT_ID=$CognitoClientId" }

        # Hook Script arguments
        $hookArgs = @()
        if (Test-Path (Join-Path $scriptsDir "zap_hooks.py")) {
             $hookArgs = @("--hook", "/zap/scripts/zap_hooks.py")
        }

        # ------------------------------------------------------
        # A. Frontend (SPA) Scan - zap-baseline.py
        # ------------------------------------------------------
        if ($TargetUrl) {
             Write-Host "  > Frontend Target: $TargetUrl" -ForegroundColor Cyan
             Run-ScanTool -Name "docker" -Description "ZAP Baseline (Frontend SPA)" -CommandBlock {
                 
                 # URL Seed File (optional - for scanning specific pages)
                 if ($UrlSeedFile -and (Test-Path $UrlSeedFile)) {
                    Write-Host "  Using URL seed file: $UrlSeedFile" -ForegroundColor Gray
                    Copy-Item $UrlSeedFile "$zapReportDir/urls.txt" -Force
                 }

                 # Run Docker
                 # -j enables Ajax Spider for better SPA coverage
                 docker run --rm `
                    -v "${dockerVolReport}:/zap/wrk/:rw" `
                    -v "${dockerVolScripts}:/zap/scripts/:ro" `
                    @envArgs `
                    -t ghcr.io/zaproxy/zaproxy:stable `
                    zap-baseline.py -t $TargetUrl -j -J zap-frontend.json -r zap-frontend.html @hookArgs
             }
        }

        # ------------------------------------------------------
        # B. API Scan - zap-api-scan.py
        # ------------------------------------------------------
        if ($TargetApiUrl) {
             Write-Host "  > API Target: $TargetApiUrl" -ForegroundColor Cyan
             Run-ScanTool -Name "docker" -Description "ZAP API Scan (Backend)" -CommandBlock {
                 
                 $openApiPath = Join-Path $scriptsDir "openapi.yaml"
                 if (-not (Test-Path $openApiPath)) {
                     Write-Error "  openapi.yaml not found in security/scripts/. Cannot run API scan."
                     return
                 }

                 # Run Docker
                 # -f openapi : Format
                 # -O : Override target URL from spec file
                 # -S : Safe mode (optional, but good for production)
                 docker run --rm `
                    -v "${dockerVolReport}:/zap/wrk/:rw" `
                    -v "${dockerVolScripts}:/zap/scripts/:ro" `
                    @envArgs `
                    -t ghcr.io/zaproxy/zaproxy:stable `
                    zap-api-scan.py -t /zap/scripts/openapi.yaml -f openapi -O $TargetApiUrl -J zap-api.json -r zap-api.html @hookArgs
             }
        }

    } else {
        Write-Warning "Docker not found. Skipping ZAP scan (Docker required for consistent execution)."
    }
}

# ==========================================================
# Completion
# ==========================================================
Write-Host "Security scan completed" -ForegroundColor Green
Write-Host "Results saved to: $BASE" -ForegroundColor Green