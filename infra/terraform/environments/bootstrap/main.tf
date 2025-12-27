# ==============================================================================
# BOOTSTRAP ENVIRONMENT - Infrastructure Foundation Setup
# ==============================================================================
# PURPOSE: This file sets up the foundational infrastructure needed before deploying the main application. 
# It creates the IAM roles and OIDC provider that allow GitHub Actions to deploy infrastructure securely.
#
# WHY BOOTSTRAP EXISTS:
# - You need admin credentials to create IAM roles
# - Once roles are created, GitHub Actions can deploy without storing AWS keys
# - This is a one-time setup that enables secure CI/CD
#
# RUN ORDER: This must be run FIRST, before any other environment
# ==============================================================================

# ------------------------------------------------------------------------------
# Terraform Configuration Block
# ------------------------------------------------------------------------------
# WHAT: Defines which version of Terraform and which providers this code needs
# WHY: Ensures everyone uses compatible versions and prevents breaking changes
#
# LEARNING NOTE:
# - "required_version" prevents older Terraform versions from running this code
# - "required_providers" downloads the AWS provider plugin from HashiCorp
# - The "~> 5.0" means "any 5.x version" but not 6.0 (allows patches, not major changes)
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws" # Official AWS provider from HashiCorp
      version = "~> 5.0"        # Pin to major version 5
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Provider Configuration
# ------------------------------------------------------------------------------
# WHAT: Configures how Terraform connects to your AWS account
# WHY: Terraform needs to know which AWS region and credentials to use
#
# SECURITY NOTE:
# - Uses named profile "terraform-admin" from ~/.aws/credentials
# - This profile should have AdministratorAccess to create IAM roles
# - After bootstrap, this profile is only needed for infrastructure changes
#
# LEARNING NOTE:
# - "region" determines where resources are created (e.g., us-east-1)
# - Never hardcode AWS access keys in Terraform files!
provider "aws" {
  region = var.aws_region # From terraform.tfvars
}

# ------------------------------------------------------------------------------
# GitHub OIDC Provider for Secure CI/CD Authentication
# ------------------------------------------------------------------------------
# WHAT: Creates an OpenID Connect (OIDC) identity provider in AWS IAM
# WHY: Allows GitHub Actions to assume AWS roles without storing AWS credentials
#
# HOW IT WORKS:
# 1. GitHub Actions generates a temporary token when a workflow runs
# 2. AWS verifies the token came from GitHub (using thumbprints)
# 3. If valid, GitHub Actions can assume roles for a limited time
# 4. No long-lived AWS access keys stored in GitHub secrets!
#
# SECURITY BENEFITS:
# - No static AWS credentials to leak or rotate
# - Tokens expire automatically after each workflow run
# - Can restrict which GitHub repos and branches can access AWS
#
# LEARNING NOTE - What is OIDC?
# OIDC (OpenID Connect) is like a security handshake between GitHub and AWS.
# Think of it as GitHub showing AWS a temporary ID badge that proves:
# - "I'm GitHub Actions"
# - "I'm running from this specific repository"
# - "I'm on this specific branch"
# AWS checks the badge and says "OK, you can use these permissions for 1 hour"
resource "aws_iam_openid_connect_provider" "github" {
  # The URL where AWS will verify GitHub's identity
  url = "https://token.actions.githubusercontent.com"

  # client_id_list: Who can request tokens from this provider
  # "sts.amazonaws.com" means AWS Security Token Service (temporary credentials)
  client_id_list = [
    "sts.amazonaws.com"
  ]

  # thumbprint_list: SSL certificate fingerprints to verify GitHub's identity
  # These are GitHub's official thumbprints (updated by GitHub if certificates change)
  # SECURITY: These prevent man-in-the-middle attacks
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub's primary thumbprint // pragma: allowlist secret 
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"  # GitHub's secondary thumbprint // pragma: allowlist secret 
  ]

  # Tags help identify and organize resources in AWS console
  tags = {
    project    = var.project # e.g., "personal-note"
    managed_by = "terraform" # Shows this was created by infrastructure-as-code
  }
}

# ------------------------------------------------------------------------------
# IAM Roles Module - Creates Roles for Different Environments
# ------------------------------------------------------------------------------
# WHAT: Calls a reusable module that creates IAM roles with specific permissions
# WHY: Separates permission logic into a reusable module for clarity
#
# ROLES CREATED BY THIS MODULE:
# 1. terraform-prod-role: For deploying production environment
# 2. cicd-runner-role: For GitHub Actions to assume and deploy
#
# LEARNING NOTE - What is a Module?
# A module is like a function in programming. Instead of copying the same
# role creation code multiple times, we write it once in the module and
# call it from here. This makes code easier to maintain and reuse.
#
# SECURITY NOTE:
# - These roles will have limited permissions (defined in the module)
# - Each role only has access to its specific environment (dev vs prod)
# - The module ensures least-privilege access
module "iam_roles" {
  # Path to the module directory (relative to this file)
  source = "../../modules/iam-roles"

  # Pass variables to the module
  # The module uses these to customize the roles it creates
  project = var.project

  # ARN of the S3 bucket where Terraform stores its state
  # The roles need permission to read/write state files
  # LEARNING NOTE: ${} is string interpolation (inserting variables into strings)
  terraform_state_bucket_arn = "arn:aws:s3:::${var.terraform_state_bucket}"

  # ARN of the GitHub OIDC provider we created above
  # Allows the roles to trust GitHub Actions
  # DEPENDENCY: This creates an implicit dependency on the OIDC provider
  github_oidc_provider_arn = aws_iam_openid_connect_provider.github.arn

  # GitHub repository in format "owner/repo"
  # Used to restrict which repo can assume these roles
  # SECURITY: Only this specific repo can use these roles
  github_repo = var.github_repo
}

# ==============================================================================
# OUTPUTS - Values to Display After Apply
# ==============================================================================
# WHAT: Outputs display values after "terraform apply" completes
# WHY: You need these ARNs to configure GitHub Actions workflows
#
# LEARNING NOTE - Why Output Values?
# After Terraform creates resources, you often need to reference them elsewhere.
# Outputs make it easy to:
# - Copy ARNs into GitHub Actions secrets
# - Reference values in other Terraform configurations
# - See important information without searching AWS console
# ==============================================================================

# ------------------------------------------------------------------------------
# Terraform Prod Role ARN
# ------------------------------------------------------------------------------
# WHAT: ARN of the role GitHub Actions assumes to deploy production environment
# WHERE TO USE: Add to GitHub secret "AWS_ROLE_TO_ASSUME_PROD"
# SECURITY: Should have stricter deployment controls (e.g., manual approval)
output "terraform_prod_role_arn" {
  description = "Role for GitHub Actions to deploy to production environment"
  value       = module.iam_roles.terraform_prod_role_arn
}

# ------------------------------------------------------------------------------
# CI/CD Runner Role ARN
# ------------------------------------------------------------------------------
# WHAT: ARN of the role that GitHub Actions initially assumes
# WHERE TO USE: Add to GitHub secret "AWS_ROLE_TO_ASSUME"
# HOW IT WORKS: GitHub assumes this role first, then can assume env-specific roles
output "cicd_runner_role_arn" {
  description = "Role for GitHub Actions CI/CD runner"
  value       = module.iam_roles.cicd_runner_role_arn
}

# ------------------------------------------------------------------------------
# GitHub OIDC Provider ARN
# ------------------------------------------------------------------------------
# WHAT: ARN of the OIDC provider that trusts GitHub
# WHERE TO USE: Reference in documentation or additional role configurations
output "github_oidc_provider_arn" {
  description = "ARN of GitHub OIDC provider for reference"
  value       = aws_iam_openid_connect_provider.github.arn
}