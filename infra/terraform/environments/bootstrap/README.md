# Bootstrap Environment

## 📚 Table of Contents
- [What is Bootstrap?](#what-is-bootstrap)
- [Why Does Bootstrap Exist?](#why-does-bootstrap-exist)
- [What Gets Created?](#what-gets-created)
- [Prerequisites](#prerequisites)
- [Configuration Files](#configuration-files)
- [Step-by-Step Setup Guide](#step-by-step-setup-guide)
- [After Bootstrap: Next Steps](#after-bootstrap-next-steps)
- [Common Issues & Troubleshooting](#common-issues--troubleshooting)
- [Security Considerations](#security-considerations)
- [Understanding the Components](#understanding-the-components)
- [Cleaning Up](#cleaning-up)

---

## What is Bootstrap?

**Bootstrap** is the **foundational infrastructure setup** that must be run **once** before deploying your main application infrastructure.

Think of it like building a house:
- **Bootstrap** = Installing utilities (electricity, water, gas lines)
- **Main Environment** = Building the actual house

### In Technical Terms:
Bootstrap creates the IAM roles and OIDC provider that allow GitHub Actions to securely deploy infrastructure to AWS **without storing permanent AWS credentials**.

---

## Why Does Bootstrap Exist?

### The Problem Without Bootstrap:

**Traditional Approach (Insecure):**
1. Create AWS access keys (permanent credentials)
2. Store them in GitHub secrets
3. Risk: If GitHub is compromised, your AWS account is compromised
4. Maintenance burden: Must rotate keys regularly

**Bootstrap Approach (Secure):**
1. Run bootstrap once with admin credentials (local only)
2. Creates IAM roles with limited permissions
3. Sets up OIDC so GitHub can get temporary credentials
4. GitHub Actions can deploy without storing AWS keys
5. Credentials expire automatically after each workflow run

### The Catch-22:
- You need AWS credentials to create IAM roles
- But you don't want to store AWS credentials in GitHub
- Solution: Use admin credentials **locally** to create roles **once**
- After that, GitHub Actions uses those roles (no keys stored!)

---

## What Gets Created?

When you run this bootstrap configuration, it creates:

### 1. GitHub OIDC Provider
```
Resource: aws_iam_openid_connect_provider.github
Purpose: Allows AWS to trust GitHub Actions
Security: Uses SSL certificate thumbprints to verify GitHub's identity
```

**What it does:**
- Establishes a trust relationship between AWS and GitHub
- Enables GitHub Actions to request temporary AWS credentials
- No permanent credentials stored anywhere!

### 2. IAM Roles (via Module)
```
Module: iam-roles
Creates:
  - terraform-prod-role: For deploying production environment
  - cicd-runner-role: For GitHub Actions CI/CD pipeline
```

**Each role has:**
- Trust policy: Only your specific GitHub repository can assume it
- Permission policy: Limited to specific AWS actions (least privilege)
- Tags: For organization and cost tracking

### 3. Outputs
The configuration outputs important values you'll need:
- Role ARNs (Amazon Resource Names) for GitHub Actions configuration
- OIDC Provider ARN for reference

---

## Prerequisites

Before running this bootstrap, you must have:

### ✅ 1. AWS Account Setup
- [ ] AWS account created and active
- [ ] AWS CLI installed on your machine
- [ ] AWS credentials configured with **AdministratorAccess**
  ```bash
  # Configure AWS CLI with a profile named "terraform-admin"
  aws configure --profile terraform-admin
  # Enter your AWS Access Key ID
  # Enter your AWS Secret Access Key
  # Enter region: ap-southeast-1 (or your preferred region)
  # Enter output format: json
  ```
- [ ] Verify credentials work:
  ```bash
  aws sts get-caller-identity --profile terraform-admin
  ```

### ✅ 2. S3 State Bucket
- [ ] Create S3 bucket for Terraform state
  ```bash
  # Replace with your bucket name from terraform.tfvars
  aws s3 mb s3://terraform-731099197523 --region ap-southeast-1 --profile terraform-admin
  ```
- [ ] Enable versioning (protects against accidental deletion)
  ```bash
  aws s3api put-bucket-versioning \
    --bucket terraform-731099197523 \
    --versioning-configuration Status=Enabled \
    --profile terraform-admin
  ```
- [ ] Enable encryption
  ```bash
  aws s3api put-bucket-encryption \
    --bucket terraform-731099197523 \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }' \
    --profile terraform-admin
  ```

### ✅ 3. DynamoDB Lock Table
- [ ] Create DynamoDB table for state locking
  ```bash
  aws dynamodb create-table \
    --table-name terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ap-southeast-1 \
    --profile terraform-admin
  ```

### ✅ 4. GitHub Repository
- [ ] GitHub repository created: `fikriimujahid/p1-serverless-web-app`
- [ ] You have admin access to this repository
- [ ] Repository name matches exactly in `terraform.tfvars`

### ✅ 5. Terraform Installed
- [ ] Terraform version >= 1.0 installed
  ```bash
  terraform version
  ```
- [ ] If not installed: [Download Terraform](https://www.terraform.io/downloads)

---

## Configuration Files

This bootstrap directory contains three key files:

### 📄 `main.tf`
**Purpose:** The actual infrastructure code  
**Contains:**
- Terraform and provider configuration
- GitHub OIDC provider resource
- IAM roles module invocation
- Output definitions

**Learning Tip:** This is heavily commented - read it to understand what gets created!

### 📄 `variables.tf`
**Purpose:** Defines what inputs this configuration needs  
**Contains:**
- Variable declarations (name, type, description)
- Default values where appropriate
- Documentation about each variable's purpose

**Learning Tip:** Think of this as the "function signature" defining parameters.

### 📄 `terraform.tfvars`
**Purpose:** Provides actual values for the variables  
**Contains:**
- Your project name
- AWS region
- S3 bucket name
- DynamoDB table name
- GitHub repository

**Learning Tip:** This is where you customize the configuration for your project.

---

## Step-by-Step Setup Guide

### Step 1: Verify Prerequisites
```bash
# Check AWS credentials
aws sts get-caller-identity --profile terraform-admin

# Check S3 bucket exists
aws s3 ls s3://terraform-731099197523 --profile terraform-admin

# Check DynamoDB table exists
aws dynamodb describe-table --table-name terraform-locks --profile terraform-admin

# Check Terraform version
terraform version
```

All commands should succeed without errors.

### Step 2: Review Configuration
```bash
# Navigate to bootstrap directory
cd infra/terraform/environments/bootstrap

# Review your variables
cat terraform.tfvars

# Verify values match your setup:
# - project: Your project name
# - aws_region: Your AWS region
# - terraform_state_bucket: Your S3 bucket name (must exist!)
# - github_repo: Your GitHub repository in "owner/repo" format
```

### Step 3: Initialize Terraform
set the AWS_PROFILE environment variable:

```bash
# Linux/Mac
export AWS_PROFILE=<profile-name>

# Windows PowerShell
$env:AWS_PROFILE="<profile-name>"

# Windows Command Prompt
set AWS_PROFILE=<profile-name>
# Download providers and modules
terraform init

# What this does:
# - Downloads AWS provider plugin
# - Initializes backend (local for bootstrap)
# - Downloads iam-roles module from ../../modules/iam-roles
```

**Expected Output:**
```
Initializing modules...
- iam_roles in ../../modules/iam-roles

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 4: Preview Changes
```bash
# See what will be created (without actually creating it)
terraform plan

# Review the output carefully:
# - aws_iam_openid_connect_provider.github will be created
# - Module resources (IAM roles) will be created
# - No resources should be destroyed or modified (first run)
```

**What to Look For:**
- Green `+` symbols = Resources to be created
- Number of resources matches expectations (~5-7 resources)
- No red `-` or `~` symbols (nothing destroyed/modified on first run)

### Step 5: Apply Configuration
```bash
# Create the infrastructure
terraform apply

# Terraform will:
# 1. Show you the plan again
# 2. Ask for confirmation: Type "yes" and press Enter
# 3. Create resources in your AWS account
# 4. Display outputs with role ARNs
```

**Expected Output:**
```
Plan: 5 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Enter a value: yes

aws_iam_openid_connect_provider.github: Creating...
aws_iam_openid_connect_provider.github: Creation complete after 2s [id=arn:aws:iam::...]
module.iam_roles.aws_iam_role.terraform_prod: Creating...
...

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

cicd_runner_role_arn = "arn:aws:iam::731099197523:role/p1-serverless-web-app-cicd-runner-role"
github_oidc_provider_arn = "arn:aws:iam::731099197523:oidc-provider/token.actions.githubusercontent.com"
terraform_prod_role_arn = "arn:aws:iam::731099197523:role/p1-serverless-web-app-terraform-prod-role"
```

### Step 6: Save Output Values
**IMPORTANT:** Copy the output ARNs - you'll need them for GitHub Actions!

```bash
# Display outputs again if needed
terraform output

# Save to a file for reference
terraform output > bootstrap-outputs.txt
```

**Copy these values:**
- `cicd_runner_role_arn`: Main role for GitHub Actions
- `terraform_prod_role_arn`: Role for production deployments
- `github_oidc_provider_arn`: OIDC provider reference

---

## After Bootstrap: Next Steps

### 1. Configure GitHub Actions
Add the role ARNs to your GitHub repository secrets:

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Add these secrets:

| Secret Name | Value | Purpose |
|------------|-------|---------|
| `AWS_ROLE_TO_ASSUME` | `<cicd_runner_role_arn>` | Main CI/CD role |
| `AWS_ROLE_TO_ASSUME_PROD` | `<terraform_prod_role_arn>` | Production deployment role |
| `AWS_REGION` | `ap-southeast-1` | Your AWS region |

### 2. Create GitHub Actions Workflow
Example `.github/workflows/deploy.yml`:
```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: terraform init
        working-directory: infra/terraform/environments/main
      
      - name: Terraform Plan
        run: terraform plan
        working-directory: infra/terraform/environments/main
      
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: infra/terraform/environments/main
```

### 3. Test the Setup
1. Push a change to your repository
2. Check GitHub Actions tab
3. Workflow should authenticate with AWS successfully
4. Verify in AWS CloudTrail that AssumeRoleWithWebIdentity was called

### 4. Deploy Main Environment
Now you can deploy your actual application infrastructure:
```bash
cd ../main
terraform init
terraform plan
terraform apply
```

---

## Security Considerations

### 🔒 Why This Approach is Secure

**Traditional Method (Insecure):**
- AWS access keys stored in GitHub secrets
- Keys are permanent (don't expire)
- If GitHub is compromised, attacker has full access
- Must manually rotate keys

**OIDC Method (Secure):**
- No permanent credentials stored anywhere
- Temporary tokens expire after 1 hour
- Tokens only work from your specific GitHub repository
- Tokens automatically rotate every workflow run
- AWS verifies GitHub's identity cryptographically

### 🔐 IAM Role Permissions

The roles created follow **principle of least privilege**:
- Only have permissions needed for Terraform operations
- Cannot perform destructive actions outside Terraform
- Scoped to specific resources (state bucket, specific regions)
- Can be audited via CloudTrail

### 🛡️ Best Practices

**DO:**
- ✅ Use a dedicated AWS profile for bootstrap (terraform-admin)
- ✅ Enable MFA on admin AWS user
- ✅ Enable S3 bucket versioning and encryption
- ✅ Review IAM policies in the iam-roles module
- ✅ Use AWS CloudTrail to monitor role usage
- ✅ Restrict who can modify bootstrap infrastructure

**DON'T:**
- ❌ Store AWS access keys in GitHub secrets
- ❌ Use root AWS account credentials
- ❌ Give roles more permissions than needed
- ❌ Share terraform-admin credentials with team
- ❌ Run terraform apply without reviewing plan
- ❌ Commit AWS credentials to Git

### 🔍 Auditing & Monitoring

After bootstrap, monitor these:
- **CloudTrail**: Log all AssumeRoleWithWebIdentity calls
- **IAM Access Analyzer**: Detect overly permissive policies
- **AWS Config**: Track IAM role changes
- **Cost Explorer**: Monitor unexpected AWS usage

---

## Understanding the Components

### What is OIDC?

**OIDC (OpenID Connect)** is an authentication protocol that lets two systems trust each other.

**Real-World Analogy:**
Think of OIDC like a security badge system at a building:
1. GitHub is the issuing authority (gives out badges)
2. AWS is the building security (checks badges)
3. GitHub issues a temporary badge when you run a workflow
4. AWS checks: "Is this badge from GitHub? Is it for the right person?"
5. If valid, AWS says "OK, come in for 1 hour"

**Technical Flow:**
```
1. GitHub Actions workflow starts
2. GitHub generates OIDC token with claims:
   - Repository: fikriimujahid/p1-serverless-web-app
   - Branch: main
   - Expiration: 1 hour
3. Workflow sends token to AWS STS
4. AWS verifies:
   - Token signed by GitHub (thumbprint check)
   - Repository matches IAM role trust policy
   - Token not expired
5. AWS issues temporary credentials (access key, secret, session token)
6. Workflow uses credentials to run Terraform
7. Credentials expire after 1 hour automatically
```

### What is Terraform State?

**State** is Terraform's database of your infrastructure.

**What's in the State File:**
```json
{
  "resources": [
    {
      "type": "aws_iam_role",
      "name": "cicd_runner",
      "attributes": {
        "arn": "arn:aws:iam::731099197523:role/...",
        "id": "p1-serverless-web-app-cicd-runner-role",
        "assume_role_policy": "..."
      }
    }
  ]
}
```

**Why State Matters:**
- Maps your code to real AWS resources
- Tracks dependencies (Resource A must exist before Resource B)
- Enables `terraform plan` to show what will change
- Without state, Terraform can't manage existing infrastructure

**Why Remote State (S3):**
- Local state = Each person has different state (chaos!)
- Remote state = Everyone shares same state (harmony!)
- S3 provides versioning, encryption, access control

### What are IAM Roles?

**IAM Roles** are like temporary security badges for AWS services or users.

**Key Concepts:**
1. **Trust Policy**: Who can assume this role?
   - Example: "Only GitHub Actions from repo X"
2. **Permission Policy**: What can this role do?
   - Example: "Can read/write S3 bucket Y"
3. **Assuming a Role**: Temporarily using a role's permissions
   - Like borrowing someone's access badge for a task

**Bootstrap Creates These Roles:**
- `cicd-runner-role`: Main role for GitHub Actions
- `terraform-prod-role`: Limited role for production deployments

---

## Cleaning Up

### ⚠️ WARNING: Only destroy if you're decommissioning the entire project!

Destroying bootstrap infrastructure will:
- Delete IAM roles (GitHub Actions can't deploy anymore)
- Delete OIDC provider (authentication broken)
- **NOT** delete your application infrastructure
- **NOT** delete S3 state bucket or DynamoDB lock table

### If You Really Want to Destroy:

```bash
# Step 1: Destroy main environment infrastructure first
cd ../main
terraform destroy

# Step 2: Destroy bootstrap
cd ../bootstrap
terraform destroy

# Step 3: Manually delete S3 bucket
aws s3 rb s3://terraform-731099197523 --force --profile terraform-admin

# Step 4: Manually delete DynamoDB table
aws dynamodb delete-table --table-name terraform-locks --profile terraform-admin
```

### Partial Cleanup (Keep State Infrastructure):
If you just want to remove IAM roles but keep state bucket:
```bash
# Remove only the IAM resources
terraform destroy -target=module.iam_roles
terraform destroy -target=aws_iam_openid_connect_provider.github
```

---

## Additional Resources

### Terraform Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Variables](https://www.terraform.io/language/values/variables)
- [Terraform State](https://www.terraform.io/language/state)

### AWS Documentation
- [IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)
- [OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [S3 Buckets](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)

### GitHub Actions
- [Configuring OIDC in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS Credentials Action](https://github.com/aws-actions/configure-aws-credentials)

---

## Questions?

If you're stuck or have questions:
1. Review the comments in `main.tf`, `variables.tf`, and `terraform.tfvars`
2. Check the [Common Issues](#common-issues--troubleshooting) section
3. Run `terraform plan` to see what would change before applying
4. Check AWS CloudTrail for authentication issues
5. Verify all prerequisites are completed

Remember: Bootstrap only runs once! After successful setup, you rarely need to touch it again.
