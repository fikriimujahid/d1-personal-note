# ==============================================================================
# TERRAFORM VARIABLES - Bootstrap Environment Configuration
# ==============================================================================
# PURPOSE: This file contains the actual values for variables used in main.tf
# 
# LEARNING NOTE - What is a .tfvars file?
# Think of variables.tf as defining "what inputs are needed" (like function parameters)
# and terraform.tfvars as providing "the actual values" (like function arguments)
#
# WHY SEPARATE FILES?
# - variables.tf: Defines variable structure (type, description, validation)
# - terraform.tfvars: Contains real values (can be different per environment)
# - This separation lets you reuse the same code with different values
#
# SECURITY WARNING:
# This file may contain sensitive values! 
# - Add terraform.tfvars to .gitignore if it contains secrets
# - Use environment variables or secret managers for truly sensitive data
# - For this bootstrap, values are references (not secrets themselves)
# ==============================================================================

# ------------------------------------------------------------------------------
# Project Name
# ------------------------------------------------------------------------------
project = "d1-personal-note"

# ------------------------------------------------------------------------------
# AWS Region
# ------------------------------------------------------------------------------
# WHAT: The geographic region where AWS resources will be created
# WHY: Determines latency, cost, and compliance requirements
aws_region = "ap-southeast-1"

# ------------------------------------------------------------------------------
# Terraform State Bucket
# ------------------------------------------------------------------------------
# WHAT: Name of the S3 bucket where Terraform stores its state file
# WHY: State file tracks which real infrastructure exists vs what's in code
#
# WHAT IS TERRAFORM STATE?
# Terraform creates a "state file" that maps your code to real AWS resources.
# For example, it remembers: "resource 'aws_iam_role.github' = arn:aws:iam::..."
# Without state, Terraform wouldn't know what already exists!
#
# WHY S3 FOR STATE?
# - LOCAL STATE: Running "terraform apply" on your laptop creates terraform.tfstate
#   → Problem: What if your teammate runs Terraform? They have a different state!
#   → Problem: If you lose your laptop, you lose the state (infrastructure orphaned)
#
# - REMOTE STATE (S3): Everyone reads/writes the same state file from S3
#   → Team collaboration: Everyone sees the same state
#   → Safety: State backed up in S3 (versioned, encrypted)
#   → Locking: DynamoDB prevents two people from running Terraform simultaneously
#
# IMPORTANT PREREQUISITES:
# This S3 bucket must exist BEFORE running "terraform init"!
# Create it manually or with a separate setup script
#
# SECURITY CONSIDERATIONS:
# - Enable versioning: Protects against accidental state file deletion
# - Enable encryption: State files may contain sensitive data (IDs, ARNs)
# - Restrict access: Only admins and CI/CD should read/write state
# - Enable logging: Track who accesses the state file
#
# Never edit state files manually! Use "terraform state" commands
terraform_state_bucket = "terraform-731099197523"

# ------------------------------------------------------------------------------
# GitHub Repository
# ------------------------------------------------------------------------------
# WHAT: Full path to your GitHub repository in "owner/repo" format
# WHY: Restricts which GitHub repo can assume AWS IAM roles
github_repo = "fikriimujahid/d1-personal-note"