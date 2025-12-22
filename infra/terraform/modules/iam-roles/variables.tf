# ==============================================================================
# IAM ROLES MODULE - INPUT VARIABLES
# ==============================================================================
#
# WHAT THIS FILE DOES:
# This file defines the input parameters (variables) that can be passed into
# the iam-roles module. Think of variables as function parameters - they allow
# the module to be reused with different values.
#
# WHY WE USE VARIABLES:
# - Makes the module reusable across environments (dev, staging, prod)
# - Keeps sensitive values separate from code
# - Makes it easy to customize behavior without changing the module code
#
# TERRAFORM CONCEPT: Variables
# Variables in Terraform are like function parameters in programming:
# - They have a name (e.g., "project")
# - They have a type (e.g., string, number, bool)
# - They can have a description (to explain what they're for)
# - They can have default values (optional)
# - They can have validation rules (to catch mistakes early)
#
# ==============================================================================

# ------------------------------------------------------------------------------
# PROJECT IDENTIFICATION
# ------------------------------------------------------------------------------
variable "project" {
  description = "Project name used to prefix all resource names for easy identification"
  type = string
  
  # LEARNING NOTE: Why no default value?
  # We intentionally don't provide a default because every project should
  # explicitly name itself. This prevents accidental resource naming conflicts.
}

# ------------------------------------------------------------------------------
# TERRAFORM STATE CONFIGURATION
# ------------------------------------------------------------------------------
variable "terraform_state_bucket_arn" {
  # WHAT: The Amazon Resource Name (ARN) of the S3 bucket storing Terraform state
  # WHY: IAM roles need permission to access this bucket to manage infrastructure
  # 
  # TERRAFORM CONCEPT: State
  # Terraform stores information about your infrastructure in a "state file".
  # This file tracks which resources exist and their current configuration.
  # Storing state in S3 allows teams to collaborate safely.
  description = "ARN of the S3 bucket where Terraform state is stored. Used to grant IAM permissions for state management."
  type = string
}

# ------------------------------------------------------------------------------
# GITHUB ACTIONS INTEGRATION (OIDC)
# ------------------------------------------------------------------------------
variable "github_oidc_provider_arn" {
  # WHAT: The ARN of the GitHub OIDC identity provider in AWS
  # WHY: Allows GitHub Actions to authenticate with AWS without storing credentials
  #
  # SECURITY CONCEPT: OIDC (OpenID Connect)
  # Traditional approach: Store AWS access keys in GitHub secrets (risky!)
  # Modern approach: Use OIDC so GitHub can request temporary credentials
  # 
  # HOW IT WORKS:
  # 1. GitHub Actions requests access during workflow run
  # 2. AWS verifies the request came from your GitHub repo
  # 3. AWS issues temporary credentials (valid for hours, not years)
  # 4. No long-lived credentials stored anywhere
  #
  # SECURITY BENEFIT: If GitHub gets compromised, attackers can't steal
  # permanent AWS credentials because none are stored.
  description = "ARN of the GitHub OIDC provider. Enables GitHub Actions to authenticate with AWS without storing credentials."
  type = string
  
  # LEARNING NOTE: Why this is better than access keys
  # Old way: Create IAM user, generate access keys, store in GitHub secrets
  # Problems: Keys never expire, hard to rotate, can leak
  # New way: GitHub proves its identity, gets temporary credentials
  # Benefits: Credentials expire automatically, no storage, can't leak
}

variable "github_repo" {
  # WHAT: Your GitHub repository identifier in owner/repository format
  # WHY: Used to restrict which GitHub repos can assume the IAM role
  #
  # SECURITY: This implements the trust policy for the IAM role. Only GitHub
  # Actions running in THIS SPECIFIC repository will be allowed to assume the
  # role and access AWS resources.
  #
  # SECURITY NOTE: This is critical for preventing unauthorized access!
  # If you set this to "*/main-branch", ANY GitHub repo could access your AWS.
  # Always use the specific owner/repo combination.
  #
  # HOW IT'S USED: This value goes into the IAM role's trust policy condition:
  # "token.actions.githubusercontent.com:sub": "repo:owner/repository:*"
  description = "GitHub repository in format 'owner/repo'. Used to restrict IAM role access to specific repository."
  type = string
}