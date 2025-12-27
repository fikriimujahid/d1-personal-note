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

Vulnerability Assessment (DAST):
  .\scan-all.ps1 -Mode va -TargetUrl https://api.dev.example.com

All Checks (Default):
  .\scan-all.ps1

==========================================================
#>

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("monthly", "on-change", "va", "all")]
    [string]$Mode = "all",

    # Required ONLY for VA (DAST)
    [string]$TargetUrl
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
    # Run-ScanTool -Name "detect-secrets" -Description "Secrets Scanning" -CommandBlock {

    #     $baselinePath = Join-Path $ProjectRoot "security\.secrets.baseline"
    #     $excludePattern = "(node_modules|\.git|\.aws-sam|dist|build|coverage|security|\.terraform|dependency-check-data|result)"

    #     Push-Location $ProjectRoot
    #     try {
    #         Write-Host "  Running detect-secrets scan..." -ForegroundColor Gray

    #         if (-not (Test-Path $baselinePath)) {
    #             Write-Host "  No baseline found. Creating initial baseline..." -ForegroundColor Yellow

    #             # Scan and save with UTF-8 encoding (no BOM) - detect-secrets requires UTF-8
    #             $tempScan = Join-Path $env:TEMP "detect-secrets-scan-$(Get-Date -Format 'yyyyMMddHHmmss').json"
    #             detect-secrets scan `
    #                 --all-files `
    #                 --exclude-files "$excludePattern" `
    #                 | Out-File -FilePath $tempScan -Encoding utf8
                
    #             # Ensure UTF-8 without BOM
    #             $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    #             $content = [System.IO.File]::ReadAllText($tempScan, $utf8NoBom)
    #             [System.IO.File]::WriteAllText($baselinePath, $content, $utf8NoBom)
    #             Remove-Item $tempScan -ErrorAction SilentlyContinue

    #             Write-Host "  Baseline created. Run audit before committing:" -ForegroundColor Cyan
    #             Write-Host "    detect-secrets audit security\.secrets.baseline" -ForegroundColor Cyan
    #             return
    #         }

    #         # Baseline exists → check for new secrets
    #         detect-secrets scan `
    #             --all-files `
    #             --exclude-files "$excludePattern" `
    #             --baseline $baselinePath

    #         if ($LASTEXITCODE -ne 0) {
    #             Write-Host "  New secrets detected!" -ForegroundColor Red
    #             Write-Host "  Run audit to review them:" -ForegroundColor Yellow
    #             Write-Host "    detect-secrets audit .secrets.baseline" -ForegroundColor Yellow
    #         }

    #         Write-Host "  No new secrets found" -ForegroundColor Green

    #         # Optional: copy baseline as daily result (read-only)
    #         Copy-Item $baselinePath "$BASE/1.secrets/detect-secrets.json" -Force

    #     } finally {
    #         Pop-Location
    #     }
    # }

    # Run-ScanTool -Name "gitleaks" -Description "Gitleaks" -CommandBlock {
    #     $reportPath = "$BASE/1.secrets/gitleaks.json"
    #     gitleaks detect --source $ProjectRoot --no-git --report-format json --report-path $reportPath
    # }
}

# ==========================================================
# 2. Dependency Scanning (Monthly Requirement)
# ==========================================================
if ($Mode -in @("monthly", "all")) {
    $depCheckOut = "$BASE/2.dependencies"
    
    # Try local dependency-check first, fallback to Docker
    # if (Get-Command "dependency-check" -ErrorAction SilentlyContinue) {
    #     Run-ScanTool -Name "dependency-check" -Description "OWASP Dependency-Check (Local)" -CommandBlock {
    #         dependency-check --scan . --format JSON --out $depCheckOut --disableAssembly
    #     }
    # } 
    # elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
    #      # Calculate relative path for Docker volume mapping
    #      $CurrentDir = $ProjectRoot
         
    #      # Normalize to forward slashes for consistent Docker volume behavior
    #      $DockerSrc = $CurrentDir.Replace('\', '/')
         
    #      # Relative path calculation
    #      $RelReportPath = $BASE.Replace($CurrentDir, "").Trim('\').Replace('\', '/')
    #      $ContainerOut = "/src/$RelReportPath/2.dependencies"

    #      # Data directory for persistence
    #      $DataDir = Join-Path $ProjectRoot "security\dependency-check-data"
    #      if (-not (Test-Path $DataDir)) {
    #         New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    #      }
    #      $DockerData = $DataDir.Replace('\', '/')

    #      Run-ScanTool -Name "docker" -Description "OWASP Dependency-Check (Docker)" -CommandBlock {
    #         Write-Host "Using Docker container: owasp/dependency-check" -ForegroundColor Gray
    #         Write-Warning "First run (or after expiration) requires downloading NVD vulnerability data. This may take several minutes."
            
    #         $DockerReport = "$BASE/2.dependencies".Replace('\', '/')
    #         docker run --rm -t --user 0 --volume "${DockerSrc}:/src:ro" --volume "${DockerData}:/usr/share/dependency-check/data" --volume "${DockerReport}:/report" owasp/dependency-check --scan /src -f JSON -f HTML -f SARIF --out /report --project "project-dependency-scan" --disableAssembly --exclude "**/node_modules/**" --exclude "**/.git/**" --exclude "**/dist/**"
    #      }
    # } else {
    #     Write-Warning "Neither 'dependency-check' nor 'docker' found. Skipping OWASP Dependency Scan."
    # }

    # Run-ScanTool -Name "npm" -Description "NPM Audit" -CommandBlock {
    #     # Find package.json files in subdirectories (e.g., frontend, api)
    #     # Using Depth 2 to search immediate subfolders but avoid deep node_modules traversal
    #     $projects = Get-ChildItem -Path $ProjectRoot -Recurse -Depth 2 -Filter "package.json" | 
    #                 Where-Object { $_.FullName -notmatch "node_modules" }

    #     if (-not $projects) {
    #         Write-Warning "  No package.json files found to audit."
    #     }

    #     foreach ($proj in $projects) {
    #         $dir = $proj.Directory.FullName
    #         $projName = $proj.Directory.Name
            
    #         # npm audit requires package-lock.json
    #         if (Test-Path (Join-Path $dir "package-lock.json")) {
    #             Write-Host "  Auditing project: $projName" -ForegroundColor Gray
                
    #             # Navigate to project directory
    #             Push-Location $dir
    #             try {
    #                 npm audit --json > "$BASE/2.dependencies/npm-audit-$projName.json"
    #             } finally {
    #                 Pop-Location
    #             }
    #         } else {
    #             Write-Warning "  Skipping $projName : No package-lock.json found (run 'npm install' first)"
    #         }
    #     }
    # }
}

# ==========================================================
# 3. Source Code Review – Automated (SAST)
# ==========================================================
if ($Mode -in @("monthly", "on-change", "all")) {
    # Run-ScanTool -Name "semgrep" -Description "Semgrep SAST" -CommandBlock {
    #     # Set UTF-8 encoding to avoid Windows encoding issues with special characters
    #     $env:PYTHONIOENCODING = "utf-8"
    #     $env:PYTHONUTF8 = "1"
        
    #     semgrep scan $ProjectRoot `
    #     --config p/ci `
    #     --config p/security-audit `
    #     --exclude security `
    #     --exclude node_modules `
    #     --json `
    #     --output "$BASE/3.sast/semgrep.json"
    # }
}

# ==========================================================
# 4. Infrastructure as Code (Monthly)
# ==========================================================
if ($Mode -in @("monthly", "all")) {
    # Run-ScanTool -Name "checkov" -Description "Checkov IaC (Infra)" -CommandBlock {
    #     $terraformPath = Join-Path $ProjectRoot "infra\terraform"
    #     checkov -d $terraformPath --output json | Out-File -FilePath "$BASE/4.iac/checkov-infra.json" -Encoding utf8
    # }

    # Run-ScanTool -Name "checkov" -Description "Checkov IaC (API)" -CommandBlock {
    #     $apiPath = Join-Path $ProjectRoot "api"
    #     checkov -d $apiPath --output json | Out-File -FilePath "$BASE/4.iac/checkov-api.json" -Encoding utf8
    # }

    Run-ScanTool -Name "tfsec" -Description "tfsec IaC" -CommandBlock {
        tfsec infra/terraform --format json > "$BASE/4.iac/tfsec.json"
    }
}

# ==========================================================
# 5. Vulnerability Assessment (VA / DAST)
# ==========================================================
if ($Mode -eq "va") {

    if (-not $TargetUrl) {
        Write-Error "TargetUrl is required when Mode=va"
        exit 1
    }

    Write-Host "Vulnerability Assessment (OWASP ZAP)" -ForegroundColor Yellow
    Write-Host "Target: $TargetUrl" -ForegroundColor Cyan

    # Baseline scan (safe, non-intrusive)
    Run-ScanTool -Name "zap-baseline.py" -Description "ZAP Baseline" -CommandBlock {
        zap-baseline.py -t $TargetUrl -J "$BASE/5.va/zap-baseline.json" -r "$BASE/5.va/zap-baseline.html"
    }
}

# ==========================================================
# Completion
# ==========================================================
Write-Host "Security scan completed" -ForegroundColor Green
Write-Host "Results saved to: $BASE" -ForegroundColor Green