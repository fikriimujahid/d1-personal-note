# ============================================================================
# IAM Role Outputs
# ============================================================================
#
# WHAT ARE OUTPUTS?
# Outputs are values that Terraform extracts from created resources and makes
# available to other modules or to users. They allow you to:
# - Share resource information between modules (parent → child or sibling)
# - Display important values after `terraform apply`
# - Integrate with other tools and scripts
#
# WHAT THESE OUTPUTS DO:
# We're extracting the Amazon Resource Names (ARNs) of our IAM roles.
# An ARN is a unique identifier in AWS that looks like:
# arn:aws:iam::123456789012:role/MyRoleName
#
# WHY EXPORT ARNS?
# Other services need these role ARNs to:
# - Assume (use) the roles in their configuration
# - Grant permissions to cross-account access
# - Set up CI/CD pipelines with proper credentials
#
# ============================================================================

# OUTPUT 1: Development Terraform Role
# Use case: Developers assume this role to safely test Terraform changes
# Security note: This role has broad permissions - use only in dev/staging
# LEARNING NOTE: Why use .arn and not just the role name?
# Because other AWS services and Terraform modules expect the FULL ARN,
# not just the role name. The ARN uniquely identifies the role across
# all AWS accounts and regions.
# output "terraform_dev_role_arn" {
#   description = "ARN of the TerraformDevRole (used for development/testing)"
#   value       = aws_iam_role.terraform_dev.arn
# }

# OUTPUT 2: Production Terraform Role
# Use case: Restricted role used ONLY for production deployments
# Security note: This role has minimal permissions (principle of least privilege)
# Only trusted CI/CD systems should use this role
# LEARNING NOTE: Separating dev and prod roles is a security best practice
# If the dev role is compromised, prod infrastructure stays protected
output "terraform_prod_role_arn" {
  description = "ARN of the TerraformProdRole (used only for production deployments)"
  value       = aws_iam_role.terraform_prod.arn
}

# OUTPUT 3: CI/CD Runner Role
# Use case: Automation/CI-CD pipelines (GitHub Actions, GitLab CI, Jenkins, etc.)
# assume this role to deploy infrastructure
# Security note: This role should be restricted to specific GitHub repos/branches
# LEARNING NOTE: This role enables secure automation
# The CI/CD system doesn't store AWS credentials - instead it uses STS AssumeRole
# This means if the CI/CD platform is compromised, attackers can only do what
# this specific role allows, not everything an admin could do
output "cicd_runner_role_arn" {
  description = "ARN of the CICDRunnerRole (used by CI/CD automation pipelines)"
  value       = aws_iam_role.cicd_runner.arn
}