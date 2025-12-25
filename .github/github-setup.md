# GitHub Setup Guide (GitHub Console Only)

**Beginner-Friendly · Step by Step · No CLI Required**

This guide explains how to set up a **secure, professional GitHub repository** using **only the GitHub web console (UI)**.

You will learn **what to click**, **why it matters**, and **how each setting fits into CI/CD** — even if you are new to GitHub.

---

## Who This Guide Is For

* Beginners to GitHub
* Teams that want **clear, safe defaults**
* Projects using **GitHub Actions CI/CD**
* Teams deploying to **AWS using OIDC (recommended)**

> ⚠️ This guide **does NOT use GitHub CLI (`gh`)**. Everything is done via the GitHub website.

---

## What You Will Set Up

By the end of this guide, your repository will have:

* Protected branches (`main`, `develop`)
* Pull Request (PR) enforcement
* CI checks that must pass before merge
* Deployment environments (`dev`, `staging`, `prod`)
* Manual approvals for production
* Secure secrets management
* A clean foundation for CI/CD

---

## Prerequisites

Before you start, make sure:

1. You have a **GitHub account**
2. You are an **Admin** of the repository
3. The repository already exists on GitHub
4. Your project will use **GitHub Actions** for CI/CD

---

# 1. Branches and Branch Protection

## Why This Matters

Branch protection prevents:

* Accidental pushes to `main`
* Breaking production code
* Skipping reviews or CI checks

This is **one of the most important safety features** in GitHub.

---

## 1.1 Identify Your Main Branches

We will assume:

* `main` → Production-ready code
* `develop` → Integration branch for development

> If your repo only has `main`, you can create `develop` later.

---

## 1.2 Open Branch Protection Settings

1. Open your repository on GitHub
2. Click **Settings** (top menu)
3. Click **Branches** (left sidebar)
4. Under **Branch protection rules**, click **Add rule**

---

## 1.3 Protect the `main` Branch

### Branch name pattern

```
main
```

This tells GitHub: “Apply this rule to the `main` branch.”

---

### Required Settings (Enable These)

✔ **Require a pull request before merging**

Why:

* Prevents direct pushes
* Forces code review

---

✔ **Require approvals** (set to at least 1)

Why:

* Ensures someone else reviews changes
* Reduces mistakes

---

✔ **Require status checks to pass before merging**

Why:

* CI must succeed (tests, lint, build)

How:

* You will see CI checks appear automatically after workflows run

---

✔ **Require branch to be up to date before merging**

Why:

* Prevents merging outdated code

---

✔ **Require linear history** (recommended)

Why:

* Cleaner Git history
* Easier rollback

---

✔ **Do NOT allow force pushes**

Why:

* Force push can delete history

---

### Save the Rule

Click **Create** or **Save changes**.

Your `main` branch is now protected.

---

## 1.4 Protect the `develop` Branch

Repeat the same steps, but use:

```
develop
```

Recommended differences:

* Require PR: ✅
* Require approvals: ✅ (can be 1)
* Require status checks: ✅
* Force push: ❌

This keeps development safe while still flexible.

---

# 2. GitHub Environments (dev / staging / prod)

## Why Environments Matter

GitHub Environments allow you to:

* Require **manual approval** before deployment
* Store **environment-specific secrets**
* Prevent deploying to `prod` accidentally

Think of environments as **deployment gates**.

---

## 2.1 Open Environments Page

1. Go to **Settings**
2. Click **Environments**
3. Click **New environment**

---

## 2.2 Create `dev` Environment

* Name: `dev`
* Click **Configure environment**

Recommended:

* No required reviewers

Why:

* `dev` should deploy automatically

---

## 2.3 Create `staging` Environment

* Name: `staging`

Recommended:

* Add **1 required reviewer**

Why:

* Prevents accidental promotion
* Allows QA or tech lead review

---

## 2.4 Create `prod` Environment

* Name: `prod`

Required settings:

✔ **Required reviewers**

* Add senior engineers / tech leads

✔ (Optional) **Deployment branches**

* Allow only `main`

Why:

* Maximum safety for production

---

# 3. Secrets Management (CRITICAL for Terraform)

## What Are Secrets?

Secrets are **encrypted values** used by GitHub Actions, such as:

* AWS role ARN
* S3 bucket for Terraform state
* Project configuration
* API keys

Secrets are **never visible in logs**.

---

## 3.1 Repository-Level Secrets (Shared Across All Environments)

### When to Use

Use repository secrets for **environment-agnostic values**:

* AWS region
* Project name
* Terraform backend settings

---

### Required Secrets to Create

1. Go to **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Add these secrets:

| Secret Name | Example Value | Purpose |
|---|---|---|
| `AWS_REGION` | `us-east-1` | AWS region for all environments |
| `PROJECT_NAME` | `personal-note` | Terraform variable: project name |
| `TF_BACKEND_BUCKET` | `my-terraform-state-bucket` | S3 bucket for Terraform state files |
| `TF_LOCK_TABLE` | `terraform-locks` | DynamoDB table for Terraform locks |

---

## 3.2 Environment-Level Secrets (Recommended for IAM Roles)

### When to Use

Use environment secrets for **environment-specific credentials**:

* Production AWS IAM roles
* Staging AWS IAM roles
* Development AWS IAM roles

---

### How to Add Environment Secrets

1. Go to **Settings → Environments**
2. Click the environment name (`dev`, `staging`, or `prod`)
3. Under **Environment secrets**, click **Add secret**

---

### Required Secrets Per Environment

Create the same secrets in each environment:

| Environment | Secret Name | Example Value |
|---|---|---|
| `dev` | `AWS_PROD_ROLE_ARN` | `arn:aws:iam::111111111111:role/github-dev-role` |
| `staging` | `AWS_STAGING_ROLE_ARN` | `arn:aws:iam::222222222222:role/github-staging-role` |
| `prod` | `AWS_DEV_ROLE_ARN` | `arn:aws:iam::333333333333:role/github-prod-role` |

> **Note:** The role ARNs come from AWS (Terraform infrastructure), not GitHub. See the AWS OIDC section below.

---

## 3.3 Why This Matters for Terraform

In the workflow file (`infra-plan-apply.yml`):

* **Repository secrets** are used to create `backend.hcl` and `terraform.tfvars`
* These files are **generated dynamically** and never committed to Git
* **Environment secrets** are used to select the correct AWS IAM role

Example from workflow:

```yaml
- name: Create terraform.tfvars
  run: |
    cat > backend.hcl <<EOF
    bucket         = "${{ secrets.TF_BACKEND_BUCKET }}"
    region         = "${{ env.AWS_REGION }}"
    dynamodb_table = "${{ secrets.TF_LOCK_TABLE }}"
    EOF
```

This creates the file **at runtime** — it never exists in Git.

# 4. GitHub Actions + AWS OIDC (Conceptual)

> You do **not** configure AWS here — only GitHub references it.

## Why OIDC?

* No long-lived AWS keys
* Short-lived credentials
* Strong security

GitHub sends an identity token to AWS.
AWS verifies:

* Repository
* Branch
* Workflow

---

## What You Store in GitHub

In GitHub, you only store:

* AWS **Role ARN** (as a secret)

Example:

```
AWS_ROLE_TO_ASSUME_PROD
```

AWS trust policy is handled separately (Terraform).

---

# 5. GitHub Actions Workflows (High Level)

You will create files under:

```
.github/workflows/
```

Typical workflows:

* `ci.yml` → PR validation
* `dev-deploy.yml` → Auto deploy to dev
* `promote.yml` → Manual promotion
* `release.yml` → Tag + release notes

---

## Environment Binding (Important)

In a workflow job:

```yaml
environment: prod
```

This tells GitHub:

* Use `prod` secrets
* Enforce reviewers

---

# 6. Releases and Tags (UI-Based)

## Why Releases Matter

* Track what is in production
* Enable rollback
* Communicate changes

---

## How to Create a Release

1. Go to **Releases**
2. Click **Draft a new release**
3. Create a tag:

```
v1.2.3
```

4. Add release notes
5. Publish

This should happen **after production deploy**.

---

# 7. Validation Checklist

After setup, confirm:

* PR to `main` cannot merge without review
* CI runs on every PR
* Deploy to `prod` requires approval
* Secrets are not visible in logs

---

# 8. Common Beginner Mistakes

❌ Pushing directly to `main`

❌ Storing AWS keys instead of OIDC

❌ No branch protection

❌ No production approval

---

# 9. Final Mental Model

Think of GitHub as:

* **Branches** → Code safety
* **PRs** → Human review
* **Actions** → Automation
* **Environments** → Deployment gates
* **Secrets** → Secure credentials

---