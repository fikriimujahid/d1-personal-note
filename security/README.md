# Application Security Testing & Compliance (DevSecOps)

This directory defines the **application security testing strategy** for this repository.
The approach aligns with **industry best practices** and explicitly satisfies the following
security testing requirements:

- Deloitte Vulnerability Assessment (VA) – Quarterly
- Vulnerability Management System (VMS) – Monthly
- Penetration Test (PT) – Yearly
- OWASP Dependency Checker – Monthly
- Source Code Review (SCR) – Major Changes to Code

All tooling used is **100% open source**, reproducible locally, and automated in CI/CD.

---

## 1. Security Testing Philosophy

Security testing is **layered**, not substituted.

> **VA, PT, and SCR are not replacements for each other.  
> When layered together, they form a holistic view of an application’s vulnerabilities.**

This repository follows a **defense-in-depth** approach combining:
- Source code analysis
- Dependency and supply-chain scanning
- Infrastructure security scanning
- Runtime vulnerability assessment
- Human-led penetration testing

---

## 2. Security Testing Coverage Overview

| Test Type | Purpose | Tooling | Frequency |
|---------|--------|--------|----------|
| Secrets Scanning | Prevent credential leakage | detect-secrets, gitleaks | Continuous |
| Source Code Review (SCR) | Identify code-level vulnerabilities | Semgrep + Manual Review | Major Changes |
| Dependency Scanning (SCA) | Detect vulnerable libraries | OWASP Dependency-Check | Monthly |
| Infrastructure as Code (IaC) | Detect cloud misconfigurations | Checkov, tfsec | Monthly |
| Vulnerability Assessment (VA) | Scan deployed app for known vulns | OWASP ZAP | Quarterly |
| Penetration Test (PT) | Simulated real-world attack | External Vendor | Yearly |

---

## 3. Vulnerability Assessment (VA) – Quarterly

### Definition
An **application-based security scan** performed against a **running, deployed application**
to identify known vulnerabilities.

### Implementation
- **Tool**: OWASP ZAP (Baseline / Full Scan)
- **Execution**: CI/CD pipeline
- **Target**: Deployed DEV environment API
- **Authentication**: Cognito JWT (test user)
- **Frequency**: Quarterly

### Notes
- VA is **automated**
- VA does **not attempt exploitation**
- VA does **not replace Penetration Testing**

### Evidence Produced
- ZAP JSON/HTML reports
- CI job logs
- Timestamped artifacts

---

## 4. Vulnerability Management System (VMS) – Monthly

### Definition
A continuous process to **identify, track, and reassess vulnerabilities**
across code, dependencies, and infrastructure.

### Tooling & Scope

| Layer | Tool | Target |
|----|----|----|
| Secrets | detect-secrets, gitleaks | Entire repository |
| Dependencies | OWASP Dependency-Check | API & Frontend |
| Source Code | Semgrep | API & Frontend |
| IaC | Checkov, tfsec | Terraform |

### Frequency
- Monthly scheduled CI scans
- On-demand local execution

### Evidence Produced
- Monthly scan reports
- Historical result folders
- CI logs

📌 VMS **does not rely on a single tool** — it is a coordinated process.

---

## 5. Penetration Test (PT) – Yearly

### Definition
A **human-led security test** designed to actively exploit vulnerabilities
and validate real-world attack scenarios.

### Implementation
- **Performed by**: External security vendor
- **Frequency**: Yearly
- **Scope**:
  - Authentication & authorization
  - Business logic
  - Data isolation
  - Rate limiting
  - Cloud misconfigurations

### Important Clarification
- Automated tools (ZAP, scanners) **do NOT replace PT**
- PT results are delivered as a **formal report**

### Evidence Produced
- Signed penetration test report (PDF)
- Risk ratings
- Remediation tracking

---

## 6. OWASP Dependency Checker – Monthly

### Requirement
> OWASP Dependency Checker – Monthly

### Implementation
- **Tool**: OWASP Dependency-Check (CLI)
- **Frequency**: Monthly (CI)
- **Targets**:
  - `package.json`
  - `package-lock.json`

### Output
- JSON reports
- CVE identifiers
- CVSS severity ratings

✔ Fully compliant with stated requirement.

---

## 7. Source Code Review (SCR) – Major Changes to Code

### Definition
An **application-based review** of source code to identify security flaws.

### Implementation

#### Automated SCR
- Semgrep (OSS rules)
- Triggered on:
  - Pull Requests
  - Release branches
  - Security-sensitive changes

#### Manual SCR
Required for:
- Authentication / authorization changes
- IAM & permissions
- Encryption / secrets handling
- Data access logic
- Infrastructure security logic

### Evidence Produced
- Pull request reviews
- Semgrep scan results
- Git commit history

📌 SCR is **code-focused** and does not replace VA or PT.

---

## 8. Local Security Scanning

Developers can execute **non-disruptive scans locally**:

```powershell
.\security\scripts\scan-all.ps1
````

Local scans include:

* Secrets scanning
* Dependency scanning
* SAST
* IaC scanning

### Why DAST Is Not Enabled Locally

* DAST targets **running systems**
* Requires authentication tokens
* Can be slow and disruptive
* Must run against controlled environments

➡ DAST (VA) is executed **only in CI against deployed DEV environments**.

---

## 9. Scan Output & Evidence Retention

All scans generate structured reports under:

```
security/result/<DD-MM-YYYY>/
```

Recommended retention:

* Minimum: 12 months
* Preferred: 24 months

Results are excluded from version control:

```gitignore
security/result/
```

---

## 10. Compliance Summary

| Requirement                        | Status               |
| ---------------------------------- | -------------------- |
| Deloitte VA – Quarterly            | ✅ Implemented        |
| VMS – Monthly                      | ✅ Implemented        |
| Penetration Test – Yearly          | ✅ Planned / External |
| OWASP Dependency Checker – Monthly | ✅ Implemented        |
| Source Code Review – Major Changes | ✅ Implemented        |

---

## 11. References

* [https://owasp.org/www-project-zap/](https://owasp.org/www-project-zap/)
* [https://owasp.org/www-project-dependency-check/](https://owasp.org/www-project-dependency-check/)
* [https://github.com/semgrep/semgrep](https://github.com/semgrep/semgrep)
* [https://github.com/bridgecrewio/checkov](https://github.com/bridgecrewio/checkov)
* [https://github.com/aquasecurity/tfsec](https://github.com/aquasecurity/tfsec)
* [https://github.com/Yelp/detect-secrets](https://github.com/Yelp/detect-secrets)
* [https://github.com/gitleaks/gitleaks](https://github.com/gitleaks/gitleaks)

```

---