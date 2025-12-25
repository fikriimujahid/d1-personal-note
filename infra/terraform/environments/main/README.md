# Terraform Main Environment (Production) README

## Overview

This directory contains the **production environment** Terraform configuration for the `d1-personal-note` project. It provisions:

- **IAM Roles & Policies**: Service roles for Lambda, Cognito, and other AWS services
- **DynamoDB Tables**: NoSQL database for storing application data
- **Cognito User Pool**: Authentication and user management
- **S3 + CloudFront + ACM**: Static website hosting with global CDN and HTTPS
- **Optional WAF**: Web Application Firewall for CloudFront protection

This is a **beginner-friendly** Terraform setup with extensive inline comments. Each resource is documented with its purpose, security implications, and common pitfalls.

---

## Prerequisites

Before you can use this configuration, ensure you have:

### 1. Bootstrap Environment Complete

The bootstrap environment creates the S3 bucket and (optionally) DynamoDB table for remote state storage. You **must** run the bootstrap first:

```bash
cd ../bootstrap
terraform init
terraform apply
```

This creates the `terraform-731099197523` bucket referenced in `backend.hcl`.

### 2. Required Tools Installed

- **Terraform** >= 1.0 ([Download](https://www.terraform.io/downloads))
- **AWS CLI** configured with credentials ([Setup Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html))

Verify installations:

```bash
terraform version
aws sts get-caller-identity
```

### 3. AWS Permissions

Your AWS credentials must have permissions to create:
- IAM roles and policies
- DynamoDB tables
- Cognito User Pools
- S3 buckets and bucket policies
- CloudFront distributions
- ACM certificates (in us-east-1)
- (Optional) WAF Web ACLs

**Security Note**: Use a dedicated IAM user or role for Terraform with least-privilege policies. Avoid using your root AWS account.

---

## File Structure

```
main/
├── backend.hcl           # S3 backend configuration (state storage)
├── main.tf               # Primary Terraform configuration (modules)
├── variables.tf          # Input variable declarations
├── terraform.tfvars      # Variable values for this environment
├── outputs.tf            # Output values after apply
└── README.md             # This file
```

### Key Files Explained

| File | Purpose | Beginner Tip |
|------|---------|--------------|
| `main.tf` | Declares providers, modules, and infrastructure | Start here to understand architecture |
| `variables.tf` | Defines input variables (types, defaults, descriptions) | Declares *what* can be configured |
| `terraform.tfvars` | Sets actual values for variables | Declares *how* things are configured |
| `backend.hcl` | Configures remote S3 state storage | Loaded via `terraform init -backend-config=backend.hcl` |
| `outputs.tf` | Exports resource IDs/ARNs for use elsewhere | View with `terraform output` |

---

## Configuration

### Variables

All environment-specific settings are in `terraform.tfvars`. Key variables:

#### Common
- `project`: Project name (affects resource naming)
- `environment`: Environment name (e.g., `prod`, `staging`, `dev`)
- `aws_region`: Primary AWS region for resources

#### Database (DynamoDB)
- `tables`: Map of DynamoDB table configurations
  - `billing_mode`: `PAY_PER_REQUEST` (on-demand) or `PROVISIONED`
  - `hash_key`/`range_key`: Primary key structure
  - `deletion_protection_enabled`: Set `true` for production!

#### Auth (Cognito)
- `cognito_tier`: `LITE` or `PLUS` (affects pricing and features)
- `password_min_length`: Minimum password length (default: 12)
- `enable_mfa`: Whether to require multi-factor authentication
- `callback_urls`: OAuth2 callback URLs for your app

#### Hosting (S3 + CloudFront)
- `bucket_name`: S3 bucket name for static assets
- `domain_name`: Primary domain (e.g., `fikri.dev`)
- `domain_aliases`: Additional domains (e.g., `["p1.fikri.dev"]`)
- `enable_waf`: Whether to attach WAF protection
- `enable_logging`: Whether to log CloudFront access logs

**Security Warning**: Never commit secrets (passwords, API keys) to `terraform.tfvars`. Use AWS Secrets Manager or SSM Parameter Store instead, and reference them via data sources.

---

## Usage

### Initial Setup

1. **Navigate to this directory**:
   ```bash
   cd infra/terraform/environments/main
   ```

2. **Initialize Terraform** (downloads providers, configures backend):
   ```bash
    # Linux/Mac
    export AWS_PROFILE=<profile-name>

    # Windows PowerShell
    $env:AWS_PROFILE="<profile-name>"

    # Windows Command Prompt
    set AWS_PROFILE=<profile-name>

   terraform init -backend-config=backend.hcl
   ```

   This connects Terraform to the S3 bucket for remote state storage.

3. **Review the configuration**:
   ```bash
   # Validate syntax
   terraform validate

   # Format code (auto-fix indentation/spacing)
   terraform fmt -recursive

   # Preview changes without applying
   terraform plan
   ```

### Deploying Infrastructure

4. **Apply the configuration**:
   ```bash
   terraform apply
   ```

   Terraform will:
   - Show a plan of changes
   - Ask for confirmation (`yes`)
   - Create/update AWS resources
   - Save outputs to state

5. **View outputs**:
   ```bash
   terraform output
   ```

   Example outputs:
   - `user_pool_id`: Cognito User Pool ID for your app
   - `table_name`: DynamoDB table name
   - `cloudfront_domain_name`: CloudFront distribution URL

---

## Understanding Terraform Concepts

### What is State?

Terraform **state** is a JSON file (`terraform.tfstate`) that maps your configuration to real AWS resources. It tracks:
- Resource IDs (e.g., `i-1234567890abcdef0` for an EC2 instance)
- Metadata and dependencies
- Sensitive values (encrypted in S3 via `encrypt = true`)

**Why remote state?**
- **Safety**: Local state files can be lost or corrupted
- **Collaboration**: Multiple team members share the same state
- **Locking**: Prevents concurrent applies that could corrupt state

### Providers

Providers are plugins that let Terraform talk to cloud APIs. This configuration uses:
- `aws` (default): Your primary region (e.g., `ap-southeast-1`)
- `aws.us_east_1` (alias): Required for CloudFront/ACM/WAF (global services)

### Modules

Modules group related resources for reusability. This configuration uses:
- `iam`: IAM roles and policies (in `../../modules/iam`)
- `database`: DynamoDB tables (in `../../modules/dynamodb`)
- `auth`: Cognito User Pools (in `../../modules/auth`)
- `hosting`: S3 + CloudFront + ACM (in `../../modules/hosting`)

**Why modules?** Keep `main.tf` clean, enable reuse across environments, and enforce consistent patterns.

### Variables vs Locals

- **Variables** (`var.*`): External inputs, set via `terraform.tfvars` or CLI flags
- **Locals** (`local.*`): Computed values for internal use (like shared tags)

Think of variables as function parameters and locals as internal variables.

---

## Common Workflows

### Making Changes

1. Edit `terraform.tfvars` or module files
2. Preview: `terraform plan`
3. Apply: `terraform apply`
4. Commit changes to Git (excluding `terraform.tfstate*`)

### Viewing Current State

```bash
# List all resources
terraform state list

# Show details of a specific resource
terraform state show module.database.aws_dynamodb_table.this["notes"]
```

### Destroying Resources

**⚠️ Danger Zone**: This deletes all infrastructure!

```bash
terraform destroy
```

Use this only for:
- Decommissioning environments
- Testing/development (not production!)
- Cost savings when resources aren't needed

**Production Safety**: Set `deletion_protection_enabled = true` on critical resources like databases.

---

## Security Best Practices

### 1. State File Security

✅ **Do**:
- Store state in S3 with `encrypt = true`
- Enable S3 bucket versioning (rollback from mistakes)
- Restrict S3 bucket access via IAM policies
- Enable DynamoDB locking to prevent conflicts

❌ **Don't**:
- Commit `terraform.tfstate` to Git (add to `.gitignore`)
- Store secrets in variables (use AWS Secrets Manager)
- Share state files via Slack/email (sensitive data inside)

### 2. IAM Least Privilege

- Review IAM policies in the `iam` module regularly
- Avoid wildcard permissions (`"*"`) in production
- Use service-specific roles (Lambda, Cognito, etc.)

### 3. Encryption

✅ **Enabled**:
- S3 state encryption (`encrypt = true` in `backend.hcl`)
- S3 website bucket encryption (`sse_algorithm = "AES256"`)
- CloudFront HTTPS via ACM certificates

⚠️ **Review**:
- DynamoDB encryption at rest (check module implementation)
- Cognito advanced security features (`enable_advanced_security`)

### 4. Logging & Monitoring

- Enable CloudFront logging (`enable_logging = true`)
- Store logs in a separate bucket from website assets
- Review CloudWatch metrics for DynamoDB, Cognito, CloudFront

### 5. WAF (Web Application Firewall)

- Enable WAF for production (`enable_waf = true`)
- Configure rate limiting (`waf_rate_limit`) to mitigate DoS attacks
- Review AWS Managed Rules for common attack patterns

---

## Troubleshooting

### Problem: `terraform init` fails with "Error configuring the backend"

**Cause**: The S3 bucket in `backend.hcl` doesn't exist or you lack permissions.

**Solution**:
1. Run the bootstrap environment first: `cd ../bootstrap && terraform apply`
2. Verify bucket exists: `aws s3 ls s3://terraform-731099197523`
3. Check AWS credentials: `aws sts get-caller-identity`

---

### Problem: "Error acquiring the state lock"

**Cause**: Another `terraform apply` is running, or a previous run crashed without releasing the lock.

**Solution**:
1. Wait for the other operation to finish (if someone else is running Terraform)
2. If stuck, manually release the lock:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```
   (Get `<LOCK_ID>` from the error message)

**Prevention**: Set up DynamoDB locking in `backend.hcl` to detect this automatically.

---

### Problem: "Error creating CloudFront Distribution: InvalidViewerCertificate"

**Cause**: ACM certificate must be in `us-east-1` for CloudFront, even if your app is in another region.

**Solution**:
- The `hosting` module uses the `aws.us_east_1` provider alias for ACM/CloudFront
- Verify the certificate exists in `us-east-1`: `aws acm list-certificates --region us-east-1`

---

### Problem: "Resource already exists" errors

**Cause**: Terraform state is out of sync with actual AWS resources.

**Solution**:
1. **Import existing resources**:
   ```bash
   terraform import module.database.aws_dynamodb_table.this["notes"] notes-table-name
   ```
2. **Or delete the existing resource** (if safe) and let Terraform recreate it

---

### Problem: Changes to `terraform.tfvars` don't apply

**Cause**: Terraform caches the plan and may not detect changes.

**Solution**:
1. Run `terraform plan` first to preview
2. Use `terraform apply -var="variable_name=value"` to override
3. Ensure you're in the correct directory (`environments/main`)

---

## Trade-offs & Alternatives

### Why S3 Backend Instead of Terraform Cloud?

**S3 Backend (current)**:
- ✅ Simple, low-cost, built-in versioning
- ✅ Works with any AWS account
- ❌ No UI for viewing state
- ❌ Manual DynamoDB setup for locking

**Terraform Cloud**:
- ✅ Web UI, team management, policy checks
- ✅ Built-in locking and state versioning
- ❌ Requires Terraform Cloud account
- ❌ Potential cost for teams/features

**Recommendation**: Start with S3 backend. Migrate to Terraform Cloud if you need advanced features.

---

### Why Modules Instead of Flat Configuration?

**Modules (current)**:
- ✅ Reusable across environments (dev, staging, prod)
- ✅ Encapsulates complexity (hosting module handles S3 + CloudFront + ACM)
- ❌ Slight learning curve for beginners

**Flat Configuration**:
- ✅ Simpler for small projects
- ❌ Duplicated code across environments
- ❌ Harder to maintain as project grows

**Recommendation**: Use modules for any project with >1 environment or >50 resources.

---

## Common Beginner Mistakes

### 1. Forgetting to Initialize

❌ Running `terraform apply` before `terraform init`

✅ Always run `terraform init -backend-config=backend.hcl` first

---

### 2. Committing State Files to Git

❌ Committing `terraform.tfstate` (contains sensitive data)

✅ Add to `.gitignore`:
```gitignore
# Terraform
*.tfstate
*.tfstate.backup
.terraform/
```

---

### 3. Hardcoding Secrets

❌ Setting passwords directly in `terraform.tfvars`:
```hcl
database_password = "MyPassword123!"  # NEVER DO THIS
```

✅ Use AWS Secrets Manager:
```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

# Reference: data.aws_secretsmanager_secret_version.db_password.secret_string
```

---

### 4. Skipping `terraform plan`

❌ Running `terraform apply` without reviewing changes first

✅ Always run `terraform plan` to preview impact

---

### 5. Not Enabling Deletion Protection

❌ Leaving `deletion_protection_enabled = false` on production databases

✅ Set to `true` in `terraform.tfvars` for critical resources

---

## Learning Resources

- **Terraform Docs**: [terraform.io/docs](https://www.terraform.io/docs)
- **AWS Provider**: [registry.terraform.io/providers/hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- **Terraform Best Practices**: [learn.hashicorp.com/tutorials/terraform/pattern-module-creation](https://learn.hashicorp.com/tutorials/terraform/pattern-module-creation)

---

## Need Help?

Review the inline comments in:
- [`main.tf`](main.tf) - High-level architecture
- [`backend.hcl`](backend.hcl) - State storage configuration
- Module READMEs in `../../modules/`

For project-specific questions, check with your team lead or create an issue in the project repository.

---

**Happy Terraforming! 🚀**
