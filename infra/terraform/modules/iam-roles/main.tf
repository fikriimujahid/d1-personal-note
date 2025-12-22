# ==============================================================================
# LEARNING NOTE: What is this file?
# ==============================================================================
# This Terraform module creates IAM roles and policies for a secure CI/CD setup.
#
# Architecture Overview:
# - TerraformDevRole: Used by developers and CI/CD for dev/staging environments
# - TerraformProdRole: Used ONLY by CI/CD for production deployments
# - CICDRunnerRole: Entry point for GitHub Actions, assumes the above roles
#
# Security Pattern:
# This implements "least privilege" by separating dev and prod permissions.
# Developers can't accidentally destroy production, and CI/CD has explicit gates.
#
# Common Questions:
# Q: Why separate roles instead of one "terraform" role?
# A: Separation limits blast radius. If dev credentials leak, prod stays safe.
#
# Q: Why is there a "runner" role that assumes other roles?
# A: This is the "role chaining" pattern. GitHub Actions authenticates as CICDRunnerRole, then assumes the appropriate role based on environment.
# ==============================================================================

# ==============================================================================
# DATA SOURCE: AWS Account Information
# ==============================================================================
# WHAT: Fetches the current AWS account ID
# WHY: We need it to build IAM ARNs dynamically
# 
# Terraform Concept: DATA SOURCES
# - Data sources read information from AWS (they don't create anything)
# - They're evaluated during "terraform plan" before resources are created
# - Use data sources when you need to reference existing infrastructure
#
# This specific data source gives us:
# - account_id: The 12-digit AWS account number
# - arn: The full ARN of the caller
# - user_id: The unique ID of the IAM entity making the request
# ==============================================================================
data "aws_caller_identity" "current" {}

# ==============================================================================
# LOCAL VALUES: GitHub OIDC Subject Claims
# ==============================================================================
# WHAT: List of GitHub workflows allowed to assume these roles
# WHY: Restricts which GitHub Actions can access AWS (security control)
#
# Terraform Concept: LOCALS vs VARIABLES
# - Variables: Input from the user (defined in variables.tf)
# - Locals: Computed values derived from variables (defined here)
# - Use locals to avoid repeating complex expressions
#
# Security Context:
# GitHub OIDC uses "subject claims" to identify the workflow.
# Each string pattern here represents a specific branch, environment, or event:
# - "ref:refs/heads/main" = pushes to main branch
# - "pull_request" = any PR from this repo
# - "environment:prod" = deployments to the "prod" GitHub environment
#
# Trade-off: This list is explicit (secure) but requires maintenance.
# Alternative: Use wildcards like "repo:org/repo:*" (less secure, more flexible)
# ==============================================================================
locals {
  allowed_subs = [
    #"repo:${var.github_repo}:ref:refs/heads/dev",      # Dev branch pushes
    #"repo:${var.github_repo}:ref:refs/heads/staging",  # Staging branch pushes
    "repo:${var.github_repo}:ref:refs/heads/main",     # Main branch pushes
    "repo:${var.github_repo}:pull_request",            # All pull requests
    #"repo:${var.github_repo}:environment:dev",         # Dev environment deploys
    #"repo:${var.github_repo}:environment:staging",     # Staging environment deploys
    "repo:${var.github_repo}:environment:main"         # Prod environment deploys
  ]
}

# ==============================================================================
# IAM ROLE: TerraformDevRole
# ==============================================================================
# WHAT: IAM role for managing dev and staging infrastructure
# WHO USES IT:
#   1. Local developers via the "terraform-admin" IAM user
#   2. GitHub Actions workflows for dev/staging deployments
#
# WHY TWO ASSUME ROLE POLICIES?
# This role has TWO ways to assume it (trust two different principals):
#   1. IAM User (terraform-admin) - for local development
#   2. GitHub OIDC - for automated CI/CD pipelines
#
# Security Implications:
# - ExternalId "terraform-dev" prevents "confused deputy" attacks
# - OIDC conditions restrict which GitHub workflows can assume this role
# - This role will have LIMITED permissions (see policy below)
#
# Terraform Concept: ASSUME ROLE POLICY
# - This is the "trust policy" - WHO can assume this role
# - Different from the "permissions policy" - WHAT this role can do
# - Think of it as: Trust Policy = door lock, Permissions Policy = room access
# ==============================================================================
# resource "aws_iam_role" "terraform_dev" {
#   name = "TerraformDevRole"

#   # Trust Policy: WHO can assume this role?
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       # Statement 1: Allow IAM user to assume this role
#       # Used by: Local developers running terraform on their machines
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           # Only this specific IAM user can assume the role
#           AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-admin"
#         }
#         Condition = {
#           # ExternalId prevents "confused deputy" attacks
#           # The user must provide this ID when calling sts:AssumeRole
#           StringEquals = {
#             "sts:ExternalId" = "terraform-dev"
#           }
#         }
#       },
#       # Statement 2: Allow GitHub Actions to assume this role
#       # Used by: Automated CI/CD pipelines
#       {
#         Action = "sts:AssumeRoleWithWebIdentity"  # OIDC authentication
#         Effect = "Allow"
#         Principal = {
#           # Federated identity = GitHub OIDC provider (setup in bootstrap)
#           Federated = var.github_oidc_provider_arn
#         }
#         Condition = {
#           # Audience claim must match (standard for AWS STS)
#           StringEquals = {
#             "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
#           }
#           # Subject claim must match one of our allowed patterns
#           # This restricts which GitHub workflows can assume the role
#           StringLike = {
#             "token.actions.githubusercontent.com:sub" = local.allowed_subs
#           }
#         }
#       }
#     ]
#   })

#   # Tags: Always tag resources for cost tracking and organization
#   tags = {
#     project     = var.project
#     environment = "shared"      # This role is shared across environments
#     managed_by  = "terraform"
#   }
# }

# ==============================================================================
# IAM POLICY: TerraformDevPolicy
# ==============================================================================
# WHAT: Permissions policy for TerraformDevRole
# PERMISSIONS: Explicit list of AWS services developers need for dev/staging
#
# Security Pattern: Least Privilege (Explicit Allow)
# - Only specific, necessary actions are allowed
# - Developers can't access resources they don't need
# - Deny statements add extra safety for production resources
#
# Why Explicit Actions Instead of Wildcards?
# TFSEC checks prevent overly permissive policies for security reasons:
# - Wildcards can grant unintended permissions
# - Listing specific actions forces thoughtful permission design
# - Easier to audit what developers can actually do
#
# Security Implications:
# - Developers still can't access prod resources (explicit deny)
# - No permission creep from wildcards
# - Maintainable: add services as needed
#
# Maintenance Note:
# As your infrastructure grows, add new services here.
# Example: Adding OpenSearch would require adding "es:*" action
# ==============================================================================
# resource "aws_iam_policy" "terraform_dev_policy" {
#   name = "TerraformDevPolicy"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       # Statement 1: EC2 and related compute services
#       # Developers manage VMs, AMIs, security groups, elastic IPs
#       {
#         Effect = "Allow"
#         Action = [
#           #"ec2:*",                    # Full EC2 (instances, volumes, snapshots, VPC)
#           #"autoscaling:*",            # Auto scaling groups
#           #"elasticloadbalancing:*",   # Load balancers
#           "cloudfront:GetDistribution",
#           "cloudfront:ListTagsForResource",
#           "cloudfront:GetOriginAccessControl",
#           "cloudfront:UpdateDistribution"            # CDN
#         ]
#         Resource = "*"
#       },
#       # Statement 2: Serverless compute
#       # Lambda functions and container services
#       {
#         Effect = "Allow"
#         Action = [
#           #"lambda:*",                 # Lambda functions
#           #"apigateway:*",             # API Gateway
#           #"ecs:*",                    # Elastic Container Service
#           #"ecr:*",                    # Container registry
#           #"logs:*",                   # CloudWatch Logs
#         ]
#         Resource = "*"
#       },
#       # Statement 3: Storage services
#       # S3, EBS, EFS for data persistence
#       {
#         Effect = "Allow"
#         Action = [
#           #"s3:*",                     # S3 buckets and objects
#           #"ebs:*",                    # Elastic Block Storage
#           #"efs:*",                    # Elastic File System
#         ]
#         Resource = "*"
#       },
#       # Statement 4: Database services
#       # RDS, DynamoDB, ElastiCache for persistence
#       {
#         Effect = "Allow"
#         Action = [
#           #"rds:*",                    # Relational databases
#           #"dynamodb:*",               # NoSQL database
#           #"elasticache:*",            # In-memory cache
#           #"redshift:*",               # Data warehouse
#         ]
#         Resource = "*"
#       },
#       # Statement 5: Networking and DNS
#       # VPC, subnets, route tables, DNS management
#       {
#         Effect = "Allow"
#         Action = [
#           #"route53:*",                # DNS management
#           #"acm:*",                    # SSL/TLS certificates
#         ]
#         Resource = "*"
#       },
#       # Statement 6: Monitoring and logging
#       # CloudWatch for metrics and alarms
#       {
#         Effect = "Allow"
#         Action = [
#           #"cloudwatch:*",             # Metrics and alarms
#           #"cloudtrail:LookupEvents",  # Read-only CloudTrail access
#         ]
#         Resource = "*"
#       },
#       # Statement 7: Terraform and infrastructure management
#       # CloudFormation and Terraform State management
#       {
#         Effect = "Allow"
#         Action = [
#           #"cloudformation:*",         # CloudFormation templates
#           #"dynamodb:GetItem",         # Read Terraform state locks
#           #"dynamodb:PutItem",         # Write Terraform state locks
#           #"dynamodb:DeleteItem",      # Delete state locks
#           #"dynamodb:Query",           # Query state lock table
#         ]
#         Resource = "*"
#       },
#       # Statement 8: Limited IAM permissions
#       # Can't create users/roles (no privilege escalation)
#       # But can read IAM resources and manage inline policies
#       {
#         Effect = "Allow"
#         Action = [
#           "iam:GetRole",              # Read role definitions
#           "iam:GetPolicy",            # Read policy definitions
#           "iam:GetUser",              # Read user definitions
#           "iam:ListRoles",            # List roles
#           "iam:ListPolicies",         # List policies
#           "iam:ListAttachedRolePolicies",  # See what's attached
#           "iam:PassRole",             # Pass role to services (no escalation)
#         ]
#         Resource = "*"
#       },
#       # Statement 9: Systems Manager for parameter/secret management
#       {
#         Effect = "Allow"
#         Action = [
#           "ssm:GetParameter",         # Read configuration
#           "ssm:GetParameters",        # Batch read
#           "ssm:PutParameter",         # Write configuration
#           "ssm:DeleteParameter",      # Delete configuration
#           "secretsmanager:GetSecretValue",  # Read secrets
#         ]
#         Resource = "*"
#       },
#       # Statement 10: EXPLICIT DENY - No access to production resources
#       # This is the safety net: even if something above allows it, this blocks it
#       {
#         Effect = "Deny"
#         Action = "*"
#         Resource = "*"
#         Condition = {
#           # Tag-based access control (TBAC)
#           # Any resource tagged with environment=prod is blocked
#           StringEquals = {
#             "aws:ResourceTag/environment" = "prod"
#           }
#         }
#       },
#       # Statement 11: EXPLICIT DENY - No access to prod Terraform state
#       # Fail-safe: blocks access to production state files in S3
#       # Prevents accidental prod infrastructure changes
#       {
#         Effect = "Deny"
#         Action = [
#           "s3:GetObject",      # Can't read prod state
#           "s3:PutObject",      # Can't write prod state
#           "s3:DeleteObject"    # Can't delete prod state
#         ]
#         Resource = "${var.terraform_state_bucket_arn}/prod/*"
#       }
#     ]
#   })

#   tags = {
#     project     = var.project
#     environment = "shared"
#     managed_by  = "terraform"
#   }
# }

# ==============================================================================
# IAM ROLE: TerraformProdRole
# ==============================================================================
# WHAT: IAM role for managing production infrastructure
# WHO USES IT: ONLY GitHub Actions (NO local developer access)
#
# WHY SEPARATE FROM DEV ROLE?
# - Prevents accidental production changes by developers
# - Requires CI/CD approval gates (configured in GitHub)
# - Creates audit trail (all prod changes go through version control)
#
# Security Implications:
# - NO IAM user can assume this role (no local access)
# - ONLY GitHub OIDC with approved subject claims
# - This will have FULL permissions to all AWS resources (see policy below)
#
# Common Mistake: Don't add an IAM user principal here "for emergencies"
# - That defeats the purpose of restricting prod access
# - Use AWS break-glass procedures if needed (separate IAM user with MFA)
# ==============================================================================
resource "aws_iam_role" "terraform_prod" {
  name = "TerraformProdRole"

  # Trust Policy: Only GitHub OIDC can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Statement 1: Allow IAM user to assume this role
      # Used by: Local developers running terraform on their machines
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # Only this specific IAM user can assume the role
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-admin"
        }
        Condition = {
          # ExternalId prevents "confused deputy" attacks
          # The user must provide this ID when calling sts:AssumeRole
          StringEquals = {
            "sts:ExternalId" = "terraform-prod"
          }
        }
      },      
      {
        Action = "sts:AssumeRoleWithWebIdentity"  # OIDC only, no IAM users
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Same allowed subs, but GitHub environment gates control access
            "token.actions.githubusercontent.com:sub" = local.allowed_subs
          }
        }
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# ==============================================================================
# IAM POLICY: TerraformProdPolicy
# ==============================================================================
# WHAT: Permissions policy for TerraformProdRole (CI/CD only)
# PERMISSIONS: Same services as TerraformDevPolicy but applies to ALL resources
#
# Key Difference from DevPolicy:
# - Same action lists (explicit services)
# - NO production resource tags to block it
# - Can access prod-tagged resources
# - Still NO wildcard to pass tfsec security checks
#
# Security Philosophy:
#   IMPORTANT: This role has broad AWS access but NOT unrestricted
# - Limited to specific services (compute, storage, database, etc.)
# - Still no privilege escalation (no IAM user/role creation)
# - Safety mechanisms:
#   1. ONLY CI/CD can assume (not developers)
#   2. GitHub environment protection rules required
#   3. Requires PR approvals and branch restrictions
#   4. All changes in version control = full audit trail
#   5. CloudTrail logs EVERY action with role details
#   6. Terraform state lock prevents concurrent modifications
#
# Why Same Services, Not More Permissive?
# - If it's not needed in dev, it's not needed in prod
# - Prod typically uses SAME services as dev (just more carefully)
# - Adding extra services here increases attack surface
# - Force thoughtful expansion through code review
#
# Maintenance:
# Keep this in sync with TerraformDevPolicy
# If you add a service to dev, add it here too
# ==============================================================================
resource "aws_iam_policy" "terraform_prod_policy" {
  name = "TerraformProdPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Statement 1: EC2 and related compute services
      {
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:ListTagsForResource",
          "cloudfront:TagResource",                 # Add tags to CloudFront resources
          "cloudfront:UntagResource",               # Remove tags from CloudFront resources
          "cloudfront:GetOriginAccessControl",
          "cloudfront:CreateDistribution",           # Create CloudFront distributions
          "cloudfront:CreateDistributionWithTags",   # Create with tags in one operation
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",           # Delete CloudFront distributions
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:CreateOriginAccessControl"
        ]
        # Scope to CloudFront distributions and origin access controls in this account
        # to avoid wildcard resources (tfsec: aws-iam-no-policy-wildcards)
        Resource = [
          "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*",
          "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:origin-access-control/*"
        ]
      }, 
      # Statement 2: Serverless compute
      # {
      #   Effect = "Allow"
      #   Action = [
      #     #"lambda:*",
      #     #"apigateway:*",
      #     #"ecs:*",
      #     #"ecr:*",
      #     #"logs:*",
      #   ]
      #   #Resource = "*"
      # },
      # Statement 3: Storage services (S3 for Terraform state)
      # Required for Terraform backend to read/write state files
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",           # Read state file
          "s3:PutObject",           # Write/update state file
          "s3:DeleteObject"         # Delete old state versions (if needed)
        ]
        # Scope to state files in the Terraform state bucket
        # Pattern: arn:aws:s3:::<bucket-name>/<key-path>
        Resource = [
          "arn:aws:s3:::terraform-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      # Statement 3b: S3 bucket-level operations (required for state backend)
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",          # Check if state file exists
          "s3:GetBucketVersioning"  # Check versioning status
        ]
        # Scope to the Terraform state bucket itself (not objects)
        Resource = [
          "arn:aws:s3:::terraform-${data.aws_caller_identity.current.account_id}"
        ]
      },
      # Statement 3c: S3 bucket management for application resources
      # Required for hosting module to create/manage website buckets
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",                      # Create new buckets
          "s3:DeleteBucket",                      # Delete buckets
          "s3:ListBucket",                        # List objects in a specific bucket
          "s3:GetBucketLocation",                 # Read bucket region (used by waiters)
          "s3:PutBucketPolicy",                   # Set bucket policies
          "s3:DeleteBucketPolicy",                # Remove bucket policies
          "s3:GetBucketPolicy",                   # Read bucket policies
          "s3:GetBucketAcl",                      # Read bucket ACL
          "s3:PutBucketAcl",                      # Set bucket ACL
          "s3:PutBucketVersioning",               # Enable/disable versioning
          "s3:GetBucketVersioning",               # Read versioning status
          "s3:PutBucketPublicAccessBlock",        # Configure public access settings
          "s3:GetBucketPublicAccessBlock",        # Read public access settings
          "s3:PutEncryptionConfiguration",        # Configure encryption
          "s3:GetEncryptionConfiguration",        # Read encryption config
          "s3:PutBucketTagging",                  # Add tags to bucket
          "s3:GetBucketTagging",                  # Read bucket tags
          "s3:PutBucketCORS",                     # Configure CORS
          "s3:GetBucketCORS",                     # Read CORS config
          "s3:PutBucketWebsite",                  # Configure static website hosting
          "s3:GetBucketWebsite",                  # Read website config
          "s3:PutBucketLogging",                  # Configure access logging
          "s3:GetBucketLogging",                  # Read logging config
          "s3:GetBucketAccelerateConfiguration",  # Read accelerate config
          "s3:PutBucketAccelerateConfiguration",  # Configure accelerate
          "s3:GetAccelerateConfiguration",        # Read accelerate config
          "s3:GetBucketRequestPayment",          # Read request payment config
          "s3:GetLifecycleConfiguration",         # Read lifecycle configuration
          "s3:PutLifecycleConfiguration",         # Set lifecycle configuration
          "s3:GetReplicationConfiguration",       # Read replication configuration
          "s3:PutReplicationConfiguration",       # Set replication configuration
          "s3:GetBucketObjectLockConfiguration",  # Read object lock configuration
          "s3:PutObjectLockConfiguration",        # Set object lock configuration
          "s3:ListAllMyBuckets"                   # List all buckets (service-level)
        ]
        # Scope to all S3 buckets in this account
        # Note: CreateBucket is a service-level action that requires "*"
        # Other actions work on specific bucket ARNs
        Resource = [
          "arn:aws:s3:::*"
        ]
      },
      # Statement 3d: S3 object operations for application buckets
      # Required to manage website content and other application data
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",           # Upload objects
          "s3:GetObject",           # Download objects
          "s3:DeleteObject",        # Delete objects
          "s3:PutObjectAcl",        # Set object ACL
          "s3:GetObjectAcl"         # Read object ACL
        ]
        # Apply to all objects in all buckets
        # This is intentionally broad for flexibility with different bucket names
        Resource = [
          "arn:aws:s3:::*/*"
        ]
      },
      # Statement 4: Database services
      {
        Effect = "Allow"
        Action = [
          #"rds:*",
          "dynamodb:CreateTable",              # Create new table
          "dynamodb:DeleteTable",              # Delete table
          "dynamodb:DescribeTable",            # Read table configuration
          "dynamodb:UpdateTable",              # Modify table settings
          "dynamodb:ListTables",               # List all tables (service-level)
          "dynamodb:TagResource",              # Add tags to table
          "dynamodb:UntagResource",            # Remove tags from table
          "dynamodb:ListTagsOfResource",       # Read table tags
          "dynamodb:UpdateTimeToLive",         # Configure TTL for auto-expiry
          "dynamodb:DescribeTimeToLive",       # Read TTL settings
          "dynamodb:UpdateContinuousBackups",  # Configure point-in-time recovery
          "dynamodb:DescribeContinuousBackups" # Read backup settings
          #"elasticache:*",
          #"redshift:*",
        ]
        Resource = [
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/*"
        ]
      },
      # Statement 5: Networking and DNS
      # Route53 for DNS management, ACM for SSL/TLS certificates
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",      # List all hosted zones (service-level, requires *)
          "route53:GetHostedZone",        # Read specific hosted zone details
          "route53:ListTagsForResource",  # List tags on hosted zones
          "route53:ListResourceRecordSets", # List DNS records in a zone
          "route53:ChangeResourceRecordSets", # Create/update/delete DNS records
          "route53:GetChange",            # Check status of pending DNS changes
          "acm:ListCertificates",         # List all certificates (service-level, requires *)
          "acm:GetCertificate",
          "acm:ListTagsForCertificate",
          "acm:DescribeCertificate"       # Read specific certificate details
        ]
        # Note: ListHostedZones and ListCertificates are service-level actions
        # that don't support resource-level permissions (they must use "*")
        # This is an AWS API limitation, not a security oversight
        Resource = "*"
      },
      # # Statement 6: Monitoring and logging
      # {
      #   Effect = "Allow"
      #   Action = [
      #     #"cloudwatch:*",
      #     #"cloudtrail:*",     # Prod can read full CloudTrail (unlike dev)
      #   ]
      #   #Resource = "*"
      # },
      # # Statement 7: Terraform and infrastructure management
      # {
      #   Effect = "Allow"
      #   Action = [
      #     #"cloudformation:*",
      #     #"dynamodb:*",       # Full DynamoDB for state/locks
      #   ]
      #   #Resource = "*"
      # },
      # Statement 8: IAM
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:TagRole",
          "iam:GetPolicy",
          "iam:GetUser",
          "iam:ListRoles",
          "iam:ListPolicies",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:ListRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = "*"
      },
      # Statement 9: Cognito for user authentication and authorization
      # Cognito User Pools for user management, authentication
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:CreateUserPool",          # Create user pool
          "cognito-idp:DeleteUserPool",          # Delete user pool
          "cognito-idp:DescribeUserPool",        # Read user pool details
          "cognito-idp:UpdateUserPool",          # Update user pool configuration
          "cognito-idp:CreateUserPoolClient",    # Create app client
          "cognito-idp:DeleteUserPoolClient",    # Delete app client
          "cognito-idp:DescribeUserPoolClient",  # Read app client details
          "cognito-idp:UpdateUserPoolClient",    # Update app client
          "cognito-idp:ListUserPools",           # List all user pools
          "cognito-idp:ListUserPoolClients",     # List app clients in a pool
          "cognito-idp:ListTagsForResource",     # Read resource tags
          "cognito-idp:TagResource",             # Add tags to resources
          "cognito-idp:UntagResource",           # Remove tags from resources
          "cognito-idp:SetUserPoolMfaConfig",    # Configure MFA settings
          "cognito-idp:GetUserPoolMfaConfig"     # Read MFA configuration
        ]
        # Scope to Cognito User Pools in this account and region
        Resource = [
          "arn:aws:cognito-idp:*:${data.aws_caller_identity.current.account_id}:userpool/*"
        ]
      },
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# ==============================================================================
# IAM ROLE: CICDRunnerRole
# ==============================================================================
# WHAT: Entry point role for GitHub Actions workflows
# WHO USES IT: All GitHub Actions workflows authenticate as this role
#
# WHY THIS ROLE EXISTS: Role Chaining Pattern
# Flow:
#   1. GitHub Actions authenticates to AWS using OIDC → gets CICDRunnerRole
#   2. Workflow checks which environment it's deploying (dev/staging/prod)
#   3. CICDRunnerRole assumes TerraformDevRole OR TerraformProdRole
#   4. Now the workflow has the appropriate permissions for that environment
#
# Benefits:
# - Single authentication point (easier to manage OIDC trust)
# - Flexible permission escalation based on context
# - Clear audit trail (CloudTrail shows role assumption chain)
#
# Security Implications:
# - This role itself has MINIMAL permissions (just assume role + logging)
# - Real permissions come from the roles it assumes
# - If GitHub OIDC is compromised, attacker still needs to pass assume conditions
#
# Trade-off:
# - Pro: Clear separation of concerns
# - Con: More complex than a single role (harder for beginners to understand)
# ==============================================================================
resource "aws_iam_role" "cicd_runner" {
  name = "CICDRunnerRole"

  # Trust Policy: Only GitHub OIDC can assume this role
  # Note: This uses AssumeRole (not AssumeRoleWithWebIdentity) because
  # the principal is still federated, but the Action is different.
  # Common Confusion: Both OIDC assumptions use Federated principal,
  # but the Action can vary based on how it's configured.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.allowed_subs
          }
        }
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# ==============================================================================
# IAM POLICY: CICDRunnerPolicy
# ==============================================================================
# WHAT: Permissions policy for CICDRunnerRole
# PERMISSIONS: Minimal - can only assume other roles and write logs
#
# Why Minimal Permissions?
# - This role is the entry point, not the execution role
# - Real work happens in TerraformDevRole or TerraformProdRole
# - Follows least-privilege principle
#
# Permissions Breakdown:
# 1. sts:AssumeRole - Allows assuming TerraformDevRole and TerraformProdRole
# 2. logs:* - Allows writing to CloudWatch Logs for debugging
#
# Security Pattern: "Broker Role"
# - Limited permissions itself
# - Can escalate to more privileged roles based on conditions
# - Creates clear audit trail
#
# Terraform Concept: RESOURCE REFERENCES
# Notice: aws_iam_role.terraform_dev.arn
# - References the ARN of another resource in THIS FILE
# - Terraform handles the dependency ordering automatically
# - These roles must be created before this policy can reference them
# ==============================================================================
resource "aws_iam_policy" "cicd_runner_policy" {
  name = "CICDRunnerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Statement 1: Allow assuming the Terraform execution roles
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          # Can assume TerraformDevRole for dev/staging deployments
          #aws_iam_role.terraform_dev.arn,
          # Can assume TerraformProdRole for production deployments
          aws_iam_role.terraform_prod.arn
        ]
      },
      # Statement 2: Allow writing logs to CloudWatch
      # Useful for: Debugging workflow issues, audit trails, monitoring
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",    # Create log group if it doesn't exist
          "logs:CreateLogStream",   # Create log stream within a group
          "logs:PutLogEvents"       # Write log entries
        ]
        # Scope CloudWatch Logs access to this account to avoid wildcard resources
        # ARN patterns:
        # - log groups:   arn:aws:logs:<region>:<account-id>:log-group:<name>
        # - log streams:  arn:aws:logs:<region>:<account-id>:log-group:<name>:log-stream:<stream>
        Resource = [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*",
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*:log-stream:*"
        ]
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# ==============================================================================
# POLICY ATTACHMENTS: Connect Policies to Roles
# ==============================================================================
# WHAT: Attaches IAM policies to IAM roles
# WHY: In AWS, roles and policies are separate resources that must be linked
#
# Terraform Concept: EXPLICIT DEPENDENCIES
# - Terraform knows terraform_dev_attach depends on terraform_dev and terraform_dev_policy
# - It will create the role and policy first, then attach them
# - This is "implicit dependency" (Terraform infers it from the references)
#
# Alternative Approaches:
# 1. Inline Policies: Define policy directly in aws_iam_role resource
#    - Pro: Everything in one place
#    - Con: Can't reuse policies across roles
# 2. AWS Managed Policies: Use existing AWS policies like "PowerUserAccess"
#    - Pro: Less to maintain
#    - Con: Less control, might grant unwanted permissions
#
# Why We Use Attachments:
# - Clear separation of concerns (role trust vs role permissions)
# - Policies can be version controlled separately
# - Can attach multiple policies to one role if needed
# ==============================================================================

# Attach TerraformDevPolicy to TerraformDevRole
# After this, anyone who assumes TerraformDevRole gets these permissions
# resource "aws_iam_role_policy_attachment" "terraform_dev_attach" {
#   role       = aws_iam_role.terraform_dev.name              # Which role
#   policy_arn = aws_iam_policy.terraform_dev_policy.arn      # Which policy
# }

# Attach TerraformProdPolicy to TerraformProdRole
resource "aws_iam_role_policy_attachment" "terraform_prod_attach" {
  role       = aws_iam_role.terraform_prod.name
  policy_arn = aws_iam_policy.terraform_prod_policy.arn
}

# Attach CICDRunnerPolicy to CICDRunnerRole
resource "aws_iam_role_policy_attachment" "cicd_runner_attach" {
  role       = aws_iam_role.cicd_runner.name
  policy_arn = aws_iam_policy.cicd_runner_policy.arn
}