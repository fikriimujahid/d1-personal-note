# ==============================================================================
# VARIABLE DEFINITIONS - Bootstrap Environment
# ==============================================================================
# PURPOSE: Defines the input variables that this Terraform configuration accepts
#
# LEARNING NOTE - What are Variables?
# Variables are like function parameters in programming. They let you:
# - Reuse the same code with different values
# - Avoid hardcoding values in your infrastructure code
# - Customize behavior without modifying the actual Terraform files
#
# HOW VARIABLES WORK:
# 1. variables.tf: Defines WHAT variables exist (this file)
#    → Specifies name, type, description, default values, validation rules
# 2. terraform.tfvars: Provides ACTUAL values for those variables
#    → Contains the real data you want to use
# 3. main.tf: USES variables with "var.variable_name" syntax
#    → References variables to configure resources
#
# ANALOGY:
# - variables.tf = Recipe listing ingredients needed
# - terraform.tfvars = Your actual ingredients in the pantry
# - main.tf = Cooking instructions using those ingredients
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Project Name Variable
# ------------------------------------------------------------------------------
# WHAT: Unique identifier for this project/application
# WHY: Used throughout infrastructure to name resources and add tags
#
# WHERE IT'S USED:
# - IAM role names: "{project}-terraform-prod-role"
# - Resource tags: project = "{project}"
# - S3 bucket prefixes, DynamoDB table names, etc.
#
# TYPE: string
# - Must be text (not a number or boolean)
# - Examples: "notesapp", "my-web-app", "api-service"
#
# VALIDATION CONSIDERATIONS (not enforced here, but best practices):
# - Use lowercase letters, numbers, and hyphens only
# - Start with a letter
# - Keep it under 32 characters for AWS naming limits
variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,31}$", var.project))
    error_message = "Project name must start with lowercase letter, contain only lowercase letters, numbers, and hyphens, and be 2-32 characters."
  }
}

# ------------------------------------------------------------------------------
# AWS Region Variable
# ------------------------------------------------------------------------------
# WHAT: The geographic AWS region where resources will be created
# WHY: Determines where your infrastructure physically runs
#
# IMPACT OF REGION CHOICE:
# - Latency: Closer to users = faster response times
# - Cost: Pricing varies by region (us-east-1 is typically cheapest)
# - Compliance: Some regulations require data to stay in specific countries
# - Service availability: Not all AWS services are available in all regions
#
# IMPORTANT:
# Once you create resources in a region, moving them is difficult!
# Choose carefully before first deployment.
variable "aws_region" {
  description = "AWS region where resources will be created (e.g., us-east-1, ap-southeast-1)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "Must be a valid AWS region format (e.g., us-east-1, ap-southeast-1)."
  }
}

# ------------------------------------------------------------------------------
# Terraform State Bucket Variable
# ------------------------------------------------------------------------------
# WHAT: Name of the S3 bucket where Terraform stores its state file
# WHY: State file tracks which real AWS resources exist vs what's in code
#
# WHAT IS STATE?
# Terraform creates a "state file" (terraform.tfstate) that acts as a database:
# - Maps your code to real AWS resources
# - Tracks resource attributes (IDs, ARNs, IP addresses)
# - Records dependencies between resources
# - Without state, Terraform can't know what exists!
#
# WHY S3 FOR STATE?
# Local state (on your laptop) has problems:
# - Team collaboration: Each person has different state
# - Loss risk: If laptop dies, state is lost (resources orphaned)
# - Concurrency: Two people can't run Terraform simultaneously
#
# Remote state in S3 solves these:
# - Single source of truth for entire team
# - Backed up and versioned in S3
# - Can enable locking via DynamoDB
# - Access controlled via IAM
#
# NO DEFAULT VALUE:
# This is REQUIRED (no default) because:
# ✓ Forces you to explicitly choose/create a bucket
# ✓ Prevents accidental use of wrong state bucket
# ✓ Each project should have its own dedicated state bucket
# ✗ There's no sensible default that works for everyone
#
# NAMING CONVENTION:
# Common patterns:
# - "terraform-{aws-account-id}" → Unique per account
# - "{project}-terraform-state" → Unique per project
# - "terraform-{company}-{project}" → Organized by company/project
#
# PREREQUISITE:
# This S3 bucket must exist BEFORE running "terraform init"!
# Create it manually first:
#   aws s3 mb s3://terraform-731099197523 --region ap-southeast-1
#
# SECURITY REQUIREMENTS:
# - Enable versioning: Protects against accidental deletions
# - Enable encryption: State may contain sensitive data
# - Block public access: State should never be publicly readable
# - Restrict IAM access: Only admins and CI/CD should access
#
# Never edit state files manually! Use "terraform state" commands.
variable "terraform_state_bucket" {
  description = "Name of the S3 bucket for storing Terraform state (must exist before running terraform init)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.terraform_state_bucket))
    error_message = "Bucket name must be 3-63 characters, lowercase letters, numbers, and hyphens only."
  }
}

# ------------------------------------------------------------------------------
# GitHub Repository Variable
# ------------------------------------------------------------------------------
# WHAT: Full path to your GitHub repository in "owner/repo" format
# WHY: Restricts which GitHub repository can assume AWS IAM roles via OIDC
#
# FORMAT REQUIREMENT: "username/repository" or "organization/repository"
# Examples:
# - Personal repo: "johndoe/my-app"
# - Organization repo: "my-company/production-api"
#
# SECURITY IMPORTANCE:
# This value is used in IAM role trust policies to restrict access:
# - Only GitHub Actions from THIS specific repo can assume roles
# - Prevents other repos (even yours) from accessing your AWS account
# - Part of the OIDC security chain
#
# HOW IT'S USED:
# The IAM role trust policy includes a condition like:
# "token.actions.githubusercontent.com:sub": "repo:{github_repo}:*"
#
# This means:
# ✅ GitHub Actions in "fikriimujahid/p1-serverless-web-app" → Access granted
# ❌ GitHub Actions in "attacker/malicious-repo" → Access denied
# ❌ GitHub Actions in your other personal repos → Access denied
#
# THE WILDCARD (*):
# "repo:{github_repo}:*" allows any branch, PR, or environment from the repo
# You can further restrict to specific branches if needed:
# - "repo:owner/name:ref:refs/heads/main" → Only main branch
# - "repo:owner/name:environment:production" → Only production environment
#
# NO DEFAULT VALUE:
# This is REQUIRED because:
# ✓ Each project has a unique repository
# ✓ Using wrong repo name = GitHub Actions authentication fails
# ✓ Security: Should never assume a default repo
# ✗ No sensible default exists
#
# HOW TO FIND YOUR VALUE:
# 1. Go to your repository: https://github.com/{owner}/{repo}
# 2. The URL structure shows: github.com/owner/repository-name
# 3. Use format: "owner/repository-name"
#
# VALIDATION CONSIDERATIONS:
# - Must contain exactly one forward slash "/"
# - Owner and repo parts must be valid GitHub names
# - Case-sensitive (though GitHub treats URLs as case-insensitive)
#
# LEARNING NOTE - Why OIDC Instead of Access Keys?
# Traditional approach (BAD):
# - Generate AWS access keys (permanent credentials)
# - Store in GitHub secrets
# - Risk: If GitHub is compromised, keys are leaked
# - Maintenance: Must rotate keys regularly
#
# OIDC approach (GOOD):
# - No permanent credentials stored anywhere
# - GitHub generates temporary token per workflow run
# - Token expires after 1 hour automatically
# - AWS verifies token came from specific repo
# - Much more secure!
variable "github_repo" {
  description = "GitHub repository in format 'owner/repo' (e.g., 'fikriimujahid/p1-serverless-web-app') - used for OIDC authentication"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_.]+/[a-zA-Z0-9-_.]+$", var.github_repo))
    error_message = "GitHub repo must be in format 'owner/repo' with valid GitHub username and repository name."
  }
}