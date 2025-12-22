# IAM Roles Module

This Terraform module creates IAM roles and policies for secure CI/CD infrastructure management using GitHub Actions OIDC authentication.

## Overview

This module implements a **role chaining pattern** to separate development and production permissions, following the principle of least privilege:

```
GitHub Actions (OIDC)
         ↓
   CICDRunnerRole (entry point)
         ↓
   ┌─────────────┐
   ↓             ↓
TerraformProdRole
```

### Key Security Features

- **OIDC Authentication**: No long-lived AWS credentials stored in GitHub
- **Role Separation**: Development and production permissions isolated
- **Least Privilege**: Explicit allow lists with no wildcard permissions
- **Audit Trail**: All actions logged through CloudTrail with role context

## Architecture

### Roles

| Role | Purpose | Who Uses It | Permissions |
|------|---------|-------------|-------------|
| `TerraformProdRole` | Production infrastructure management | CI/CD only (no local access) | Full permissions to specified AWS services |
| `CICDRunnerRole` | GitHub Actions entry point | All GitHub workflows | Can only assume other roles + write CloudWatch logs |

### Security Pattern: Role Chaining

1. **Authentication**: GitHub Actions authenticates using OIDC → assumes `CICDRunnerRole`
2. **Authorization**: Workflow determines target environment
3. **Escalation**: `CICDRunnerRole` assumes `TerraformProdRole`
4. **Execution**: Workflow executes with appropriate environment permissions

This pattern provides:
- Single OIDC trust configuration
- Environment-based permission escalation
- Clear audit trail showing role assumption chain

## Usage

### Basic Example

```hcl
module "iam_roles" {
  source = "./modules/iam-roles"

  project                    = "my-project"
  github_repo                = "owner/repository"
  github_oidc_provider_arn   = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  terraform_state_bucket_arn = "arn:aws:s3:::my-terraform-state-bucket"
}
```

### GitHub Actions Workflow Example

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.CICD_RUNNER_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Assume Production Role
        run: |
          CREDS=$(aws sts assume-role \
            --role-arn ${{ secrets.TERRAFORM_PROD_ROLE_ARN }} \
            --role-session-name github-actions-prod)
          echo "AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')" >> $GITHUB_ENV
          echo "AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')" >> $GITHUB_ENV
          echo "AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')" >> $GITHUB_ENV
      
      - name: Deploy with Terraform
        run: |
          terraform init
          terraform apply -auto-approve
```

## Variables

### Required Variables

| Name | Type | Description |
|------|------|-------------|
| `project` | `string` | Project name used to prefix all resource names |
| `github_repo` | `string` | GitHub repository in format `owner/repo` (restricts role access) |
| `github_oidc_provider_arn` | `string` | ARN of the GitHub OIDC provider in AWS |
| `terraform_state_bucket_arn` | `string` | ARN of the S3 bucket where Terraform state is stored |

### Variable Examples

```hcl
project                    = "acme-corp"
github_repo                = "acme-corp/infrastructure"
github_oidc_provider_arn   = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
terraform_state_bucket_arn = "arn:aws:s3:::acme-terraform-state"
```

## Outputs

| Name | Description |
|------|-------------|
| `terraform_prod_role_arn` | ARN of TerraformProdRole (for production deployments) |
| `cicd_runner_role_arn` | ARN of CICDRunnerRole (for CI/CD authentication) |

## Permissions

### TerraformProdRole Permissions

Currently allows limited CloudFront operations:
- `cloudfront:GetDistribution`
- `cloudfront:ListTagsForResource`
- `cloudfront:GetOriginAccessControl`
- `cloudfront:UpdateDistribution`

**Note**: Most service permissions are commented out. Uncomment and expand as your infrastructure requirements grow.

### CICDRunnerRole Permissions

Minimal permissions following least privilege:
- `sts:AssumeRole` - Can assume TerraformProdRole
- `logs:*` - Can write to CloudWatch Logs (scoped to account)

## GitHub OIDC Configuration

### Allowed Subject Claims

The module restricts which GitHub workflows can assume roles using subject claims:

```hcl
allowed_subs = [
  "repo:owner/repository:ref:refs/heads/main",     # Pushes to main branch
  "repo:owner/repository:pull_request",            # All pull requests
  "repo:owner/repository:environment:main"         # Main environment deploys
]
```

### Trust Policy Conditions

Roles require:
- **Audience**: Must be `sts.amazonaws.com`
- **Subject**: Must match one of the allowed patterns above

This prevents unauthorized GitHub repositories from assuming your AWS roles.

## Security Considerations

### Principle of Least Privilege

- **Explicit Actions**: No wildcard (`*`) permissions to pass security scans (tfsec)
- **Resource Scoping**: Where possible, permissions scoped to specific resources
- **No IAM User Access**: TerraformProdRole can ONLY be assumed via OIDC (no break-glass IAM users)

### Audit and Monitoring

All role assumptions are logged in CloudTrail with:
- Source identity (GitHub repository, workflow, commit)
- Assumed role ARN
- Actions performed
- Timestamps

### Maintenance Notes

When adding new AWS services:
1. Add specific actions to the appropriate policy
2. Keep dev and prod policies synchronized
3. Scope resources when possible (avoid `Resource = "*"`)
4. Test in dev before deploying to prod

## Prerequisites

Before using this module:

1. **GitHub OIDC Provider**: Must be created in your AWS account (typically in bootstrap)
2. **Terraform State Bucket**: S3 bucket for state storage must exist
3. **GitHub Repository**: Repository must exist and be accessible
4. **GitHub Environments** (optional but recommended): Configure environment protection rules

## Common Issues

### Issue: "Not authorized to perform: sts:AssumeRole"

**Cause**: GitHub workflow subject claim doesn't match allowed patterns

**Solution**: Verify:
- Repository name matches `github_repo` variable exactly
- Branch/environment matches one of the `allowed_subs` patterns
- OIDC provider ARN is correct

### Issue: "Access Denied" when accessing AWS services

**Cause**: Required permissions not in role policy

**Solution**: 
1. Identify the required AWS action from the error
2. Add the action to the appropriate policy statement
3. Apply the Terraform changes
4. Re-run the workflow

## Examples

### Adding a New AWS Service

To add RDS permissions:

```hcl
# In terraform_prod_policy, add to Statement 4 (Database services):
{
  Effect = "Allow"
  Action = [
    "rds:CreateDBInstance",
    "rds:DeleteDBInstance",
    "rds:DescribeDBInstances",
    "rds:ModifyDBInstance",
    "rds:AddTagsToResource",
  ]
  Resource = "arn:aws:rds:*:${data.aws_caller_identity.current.account_id}:db:*"
}
```

### Custom Subject Claims

To allow different GitHub workflows:

```hcl
locals {
  allowed_subs = [
    "repo:owner/repo:ref:refs/heads/main",
    "repo:owner/repo:environment:production",
    "repo:owner/repo:ref:refs/tags/v*",  # Allow version tags
  ]
}
```

## Resources Created

This module creates:
- 2 IAM Roles (TerraformProdRole, CICDRunnerRole)
- 2 IAM Policies (TerraformProdPolicy, CICDRunnerPolicy)
- 2 IAM Role Policy Attachments

All resources are tagged with:
- `project`: Your project name
- `environment`: "shared"
- `managed_by`: "terraform"

## License

This module is part of your internal infrastructure and follows your organization's licensing.

## Authors

Infrastructure Team

## Changelog

### v1.0.0
- Initial release
- Support for GitHub OIDC authentication
- Production role with limited CloudFront permissions
- CI/CD runner role for GitHub Actions
