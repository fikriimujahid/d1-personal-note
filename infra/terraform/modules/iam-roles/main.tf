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
# A: This is the "role chaining" pattern. GitHub Actions authenticates as CICDRunnerRole,
#    then assumes the appropriate role based on environment.
# ==============================================================================

# ==============================================================================
# DATA SOURCE: AWS Account Information
# ------------------------------------------------------------------------------
# WHAT: Fetches the current AWS account ID
# WHY: We need it to build IAM ARNs dynamically
# ==============================================================================
data "aws_caller_identity" "current" {}

# ==============================================================================
# LOCALS: GitHub OIDC Subjects (who may assume roles)
# ------------------------------------------------------------------------------
# WHAT: List of GitHub workflows allowed to assume these roles
# WHY: Restricts which GitHub Actions can access AWS (security control)
# ==============================================================================
locals {
  allowed_subs = [
    #"repo:${var.github_repo}:ref:refs/heads/dev",      # Dev branch pushes
    #"repo:${var.github_repo}:ref:refs/heads/staging",  # Staging branch pushes
    "repo:${var.github_repo}:ref:refs/heads/main",     # Main branch pushes
    "repo:${var.github_repo}:pull_request/*",          # All pull requests (requires wildcard)
    #"repo:${var.github_repo}:environment:dev",         # Dev environment deploys
    #"repo:${var.github_repo}:environment:staging",     # Staging environment deploys
    "repo:${var.github_repo}:environment:prod",        # Prod environment deploys (matches GitHub "prod" environment)
    "repo:${var.github_repo}:environment:main"         # Main environment deploys (alternative naming)
  ]
}

# ==============================================================================
# LOCALS: ARN helpers, reusable action groups, and shared tags
# ------------------------------------------------------------------------------
# Why: Centralize common strings to avoid duplication across policies/statements
# ==============================================================================
locals {
  # Account helper
  account_id = data.aws_caller_identity.current.account_id

  # Common ARN patterns
  apigw_restapi_arns   = [
    "arn:aws:apigateway:*::/*"
  ]
  logs_group_arns = [
    "arn:aws:logs:*:${local.account_id}:log-group:*",
    "arn:aws:logs:*:${local.account_id}:log-group:*:log-stream:*"
  ]
  cloudfront_arns = [
    "arn:aws:cloudfront::${local.account_id}:distribution/*",
    "arn:aws:cloudfront::${local.account_id}:origin-access-control/*"
  ]
  s3_state_bucket_arn = "arn:aws:s3:::terraform-${local.account_id}"
  s3_state_object_arn = "${local.s3_state_bucket_arn}/*"
  cognito_userpool_arns = "arn:aws:cognito-idp:*:${local.account_id}:userpool/*"

  # Action groups by service
  cloudformation_actions = [
    "cloudformation:CreateChangeSet",
    "cloudformation:DescribeChangeSet",
    "cloudformation:ExecuteChangeSet",
    "cloudformation:DeleteChangeSet",
    "cloudformation:CreateStack",
    "cloudformation:UpdateStack",
    "cloudformation:DeleteStack",
    "cloudformation:DescribeStacks",
    "cloudformation:DescribeStackEvents",
    "cloudformation:DescribeStackResources",
    "cloudformation:GetTemplate",
    "cloudformation:ListStacks",
    "cloudformation:ListStackResources",
    "cloudformation:ValidateTemplate",
    "cloudformation:GetTemplateSummary"
  ]

  lambda_actions = [
    "lambda:CreateFunction",
    "lambda:DeleteFunction",
    "lambda:GetFunction",
    "lambda:GetFunctionConfiguration",
    "lambda:UpdateFunctionCode",
    "lambda:UpdateFunctionConfiguration",
    "lambda:ListFunctions",
    "lambda:ListVersionsByFunction",
    "lambda:PublishVersion",
    "lambda:CreateAlias",
    "lambda:DeleteAlias",
    "lambda:UpdateAlias",
    "lambda:GetAlias",
    "lambda:ListAliases",
    "lambda:AddPermission",
    "lambda:RemovePermission",
    "lambda:GetPolicy",
    "lambda:TagResource",
    "lambda:UntagResource",
    "lambda:ListTags"
  ]

  apigateway_actions = [
    "apigateway:POST",
    "apigateway:GET",
    "apigateway:PUT",
    "apigateway:PATCH",
    "apigateway:DELETE",
    "apigateway:UpdateRestApiPolicy"
  ]

  logs_actions = [
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "logs:DescribeLogGroups",
    "logs:DescribeLogStreams",
    "logs:DeleteLogGroup",
    "logs:PutRetentionPolicy",
    "logs:TagLogGroup",
    "logs:UntagLogGroup"
  ]

  iam_actions = [
    "iam:GetRole",
    "iam:TagRole",
    "iam:GetPolicy",
    "iam:GetUser",
    "iam:ListRoles",
    "iam:ListPolicies",
    "iam:ListAttachedRolePolicies",
    "iam:AttachRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PassRole",
    "iam:CreateRole",
    "iam:CreateServiceLinkedRole",
    "iam:ListRolePolicies",
    "iam:ListInstanceProfilesForRole",
    "iam:DeleteRole",
    "iam:PutRolePolicy",
    "iam:GetRolePolicy",
    "iam:DeleteRolePolicy"
  ]

  cognito_actions = [
    "cognito-idp:CreateUserPool",
    "cognito-idp:DeleteUserPool",
    "cognito-idp:DescribeUserPool",
    "cognito-idp:UpdateUserPool",
    "cognito-idp:CreateUserPoolClient",
    "cognito-idp:DeleteUserPoolClient",
    "cognito-idp:DescribeUserPoolClient",
    "cognito-idp:UpdateUserPoolClient",
    "cognito-idp:ListUserPools",
    "cognito-idp:ListUserPoolClients",
    "cognito-idp:ListTagsForResource",
    "cognito-idp:TagResource",
    "cognito-idp:UntagResource",
    "cognito-idp:SetUserPoolMfaConfig",
    "cognito-idp:GetUserPoolMfaConfig"
  ]

  # CloudFront actions (used by both dev/prod policies)
  cloudfront_actions = [
    "cloudfront:GetDistribution",
    "cloudfront:ListTagsForResource",
    "cloudfront:TagResource",                  # Add tags to CloudFront resources
    "cloudfront:UntagResource",                # Remove tags from CloudFront resources
    "cloudfront:GetOriginAccessControl",
    "cloudfront:CreateDistribution",           # Create CloudFront distributions
    "cloudfront:CreateDistributionWithTags",   # Create with tags in one operation
    "cloudfront:UpdateDistribution",
    "cloudfront:DeleteDistribution",           # Delete CloudFront distributions
    "cloudfront:DeleteOriginAccessControl",
    "cloudfront:UpdateOriginAccessControl",
    "cloudfront:CreateOriginAccessControl"
  ]

  # S3 actions for Terraform state objects/bucket
  s3_state_object_actions = [
    "s3:GetObject",   # Read state file
    "s3:PutObject",   # Write/update state file
    "s3:DeleteObject" # Delete old state versions (if needed)
  ]
  s3_state_bucket_actions = [
    "s3:ListBucket",          # Check if state file exists
    "s3:GetBucketVersioning"  # Check versioning status
  ]

  # S3 bucket-level management for application buckets
  s3_bucket_actions = [
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
    "s3:GetBucketRequestPayment",           # Read request payment config
    "s3:GetLifecycleConfiguration",         # Read lifecycle configuration
    "s3:PutLifecycleConfiguration",         # Set lifecycle configuration
    "s3:GetReplicationConfiguration",       # Read replication configuration
    "s3:PutReplicationConfiguration",       # Set replication configuration
    "s3:GetBucketObjectLockConfiguration",  # Read object lock configuration
    "s3:PutObjectLockConfiguration",        # Set object lock configuration
    "s3:ListAllMyBuckets"                   # List all buckets (service-level)
  ]

  # S3 object-level operations for application buckets
  s3_object_actions = [
    "s3:PutObject",   # Upload objects
    "s3:GetObject",   # Download objects
    "s3:DeleteObject",# Delete objects
    "s3:PutObjectAcl",# Set object ACL
    "s3:GetObjectAcl" # Read object ACL
  ]

  # DynamoDB management for application tables
  dynamodb_actions = [
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
  ]

  # Route53 + ACM actions
  route53_acm_actions = [
    "route53:ListHostedZones",      # List all hosted zones (service-level)
    "route53:GetHostedZone",        # Read specific hosted zone details
    "route53:ListTagsForResource",  # List tags on hosted zones
    "route53:ListResourceRecordSets", # List DNS records in a zone
    "route53:ChangeResourceRecordSets", # Create/update/delete DNS records
    "route53:GetChange",            # Check status of pending DNS changes
    "acm:ListCertificates",         # List all certificates (service-level)
    "acm:GetCertificate",
    "acm:ListTagsForCertificate",
    "acm:DescribeCertificate"       # Read specific certificate details
  ]

  # Shared tags to keep tagging consistent without duplication
  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }

  # Resource scopes by environment: dev vs prod
  # Actions are shared; only resources differ by environment where applicable
  dev_resources = {
    cloudfront_distributions = [
      "arn:aws:cloudfront::${local.account_id}:distribution/*",
      "arn:aws:cloudfront::${local.account_id}:origin-access-control/*"
    ]
    s3_state_objects = ["arn:aws:s3:::terraform-${local.account_id}/*"]
    s3_state_bucket  = ["arn:aws:s3:::terraform-${local.account_id}"]
    s3_buckets       = ["arn:aws:s3:::*"]
    s3_objects       = ["arn:aws:s3:::*/*"]
    dynamodb_tables  = ["arn:aws:dynamodb:*:${local.account_id}:table/*"]
    route53_acm      = ["*"]
    cf_stacks        = [
      "arn:aws:cloudformation:*:${local.account_id}:stack/*-stack-dev*/*",
      # SAM CLI default stack used during guided deployments
      "arn:aws:cloudformation:*:${local.account_id}:stack/aws-sam-cli-managed-default/*",
      # SAM transforms (required for serverless deployments)
      "arn:aws:cloudformation:*:aws:transform/*"
    ]
    lambda_functions = ["arn:aws:lambda:*:${local.account_id}:function:${var.project}*-dev*"]
    apigw_restapis   = local.apigw_restapi_arns
    logs_groups      = local.logs_group_arns
    iam_all          = ["*"]
    cognito_userpools = [local.cognito_userpool_arns]
  }

  prod_resources = {
    cloudfront_distributions = [
      "arn:aws:cloudfront::${local.account_id}:distribution/*",
      "arn:aws:cloudfront::${local.account_id}:origin-access-control/*"
    ]
    s3_state_objects = ["arn:aws:s3:::terraform-${local.account_id}/*"]
    s3_state_bucket  = ["arn:aws:s3:::terraform-${local.account_id}"]
    s3_buckets       = ["arn:aws:s3:::*"]
    s3_objects       = ["arn:aws:s3:::*/*"]
    dynamodb_tables  = ["arn:aws:dynamodb:*:${local.account_id}:table/*"]
    route53_acm      = ["*"]
    cf_stacks        = [
      "arn:aws:cloudformation:*:${local.account_id}:stack/*-stack-main*/*",
      # SAM CLI default stack used during guided deployments
      "arn:aws:cloudformation:*:${local.account_id}:stack/aws-sam-cli-managed-default/*",
      # SAM transforms (required for serverless deployments)
      "arn:aws:cloudformation:*:aws:transform/*"
    ]
    lambda_functions = ["arn:aws:lambda:*:${local.account_id}:function:${var.project}*-main*"]
    apigw_restapis   = local.apigw_restapi_arns
    logs_groups      = local.logs_group_arns
    iam_all          = ["*"]
    cognito_userpools = [local.cognito_userpool_arns]
  }
}

# ==============================================================================
# IAM ROLE: TerraformDevRole (commented – kept for reference)
# ------------------------------------------------------------------------------
# WHAT: IAM role for managing dev and staging infrastructure
# WHO USES IT:
#   1. Local developers via the "terraform-admin" IAM user
#   2. GitHub Actions workflows for dev/staging deployments
# NOTE: Left commented to preserve current behavior of the module
# ==============================================================================
# resource "aws_iam_role" "terraform_dev" {
#   name = "TerraformDevRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-admin"
#         }
#         Condition = {
#           StringEquals = {
#             "sts:ExternalId" = "terraform-dev"
#           }
#         }
#       },
#       {
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Effect = "Allow"
#         Principal = {
#           Federated = var.github_oidc_provider_arn
#         }
#         Condition = {
#           StringEquals = {
#             "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
#           }
#           StringLike = {
#             "token.actions.githubusercontent.com:sub" = local.allowed_subs
#           }
#         }
#       }
#     ]
#   })
#   tags = local.tags
# }

# ==============================================================================
# IAM POLICY: TerraformDevPolicy
# ------------------------------------------------------------------------------
# WHAT: Permissions policy for TerraformDevRole
# Maintenance Note: Preserved as-is (JSON) to avoid behavioral changes
# ==============================================================================
data "aws_iam_policy_document" "terraform_dev_policy_doc" {
  # CloudFront management (same actions as prod, dev-scoped resources)
  statement {
    sid       = "CloudFrontManagement"
    effect    = "Allow"
    actions   = local.cloudfront_actions
    resources = local.dev_resources.cloudfront_distributions
  }

  # S3 for Terraform state (objects)
  statement {
    sid       = "S3StateObjects"
    effect    = "Allow"
    actions   = local.s3_state_object_actions
    resources = local.dev_resources.s3_state_objects
  }

  # S3 for Terraform state (bucket-level)
  statement {
    sid       = "S3StateBucket"
    effect    = "Allow"
    actions   = local.s3_state_bucket_actions
    resources = local.dev_resources.s3_state_bucket
  }

  # S3 bucket management for application buckets
  statement {
    sid       = "S3BucketManagement"
    effect    = "Allow"
    actions   = local.s3_bucket_actions
    resources = local.dev_resources.s3_buckets
  }

  # S3 object operations for application buckets
  statement {
    sid       = "S3ObjectOperations"
    effect    = "Allow"
    actions   = local.s3_object_actions
    resources = local.dev_resources.s3_objects
  }

  # DynamoDB table management for application data
  statement {
    sid       = "DynamoDBManagement"
    effect    = "Allow"
    actions   = local.dynamodb_actions
    resources = local.dev_resources.dynamodb_tables
  }

  # Route53 & ACM (DNS and certificates)
  statement {
    sid       = "Route53AndACM"
    effect    = "Allow"
    actions   = local.route53_acm_actions
    resources = local.dev_resources.route53_acm
  }

  # CloudFormation (SAM deployments)
  statement {
    sid       = "CloudFormationForSAM"
    effect    = "Allow"
    actions   = local.cloudformation_actions
    resources = local.dev_resources.cf_stacks
  }

  # Lambda (SAM deployments)
  statement {
    sid       = "LambdaForSAM"
    effect    = "Allow"
    actions   = local.lambda_actions
    resources = local.dev_resources.lambda_functions
  }

  # API Gateway (SAM deployments)
  statement {
    sid       = "ApiGatewayForSAM"
    effect    = "Allow"
    actions   = local.apigateway_actions
    resources = local.dev_resources.apigw_restapis
  }

  # CloudWatch Logs (Lambda logging)
  statement {
    sid       = "CloudWatchLogs"
    effect    = "Allow"
    actions   = local.logs_actions
    resources = local.dev_resources.logs_groups
  }

  # IAM (read and inline policy ops required by SAM/CFN)
  statement {
    sid       = "IAMOperations"
    effect    = "Allow"
    actions   = local.iam_actions
    resources = local.dev_resources.iam_all
  }

  # Cognito (user pools)
  statement {
    sid       = "CognitoUserPools"
    effect    = "Allow"
    actions   = local.cognito_actions
    resources = local.dev_resources.cognito_userpools
  }

  # Explicit deny: No access to production-tagged resources
  statement {
    sid     = "DenyProdTaggedResources"
    effect  = "Deny"
    actions = ["*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/environment"
      values   = ["main"]
    }
  }

  # Explicit deny: No access to prod Terraform state prefix
  statement {
    sid       = "DenyProdStateObjects"
    effect    = "Deny"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.terraform_state_bucket_arn}/main/*"]
  }
}

resource "aws_iam_policy" "terraform_dev_policy" {
  name   = "TerraformDevPolicy"
  policy = data.aws_iam_policy_document.terraform_dev_policy_doc.json

  tags = local.tags
}

# ==============================================================================
# TRUST POLICIES (data): Extracted for clarity and reuse
# ------------------------------------------------------------------------------
# These produce the exact same JSON trust policies used by roles below.
# ==============================================================================

data "aws_iam_policy_document" "terraform_prod_trust" {
  statement {
    sid     = "AllowTerraformAdminUser"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-admin"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["terraform-prod"]
    }
  }

  statement {
    sid     = "AllowGitHubOIDC"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subs
    }
  }
}

data "aws_iam_policy_document" "cicd_runner_trust" {
  statement {
    sid     = "AllowGitHubOIDC"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subs
    }
  }
}

# ==============================================================================
# IAM ROLE: TerraformProdRole
# ------------------------------------------------------------------------------
# WHAT: IAM role for managing production infrastructure
# WHO USES IT: GitHub Actions (and currently terraform-admin per existing trust)
# NOTE: Behavior preserved exactly as before
# ==============================================================================
resource "aws_iam_role" "terraform_prod" {
  name               = "TerraformProdRole"
  assume_role_policy = data.aws_iam_policy_document.terraform_prod_trust.json

  tags = local.tags
}

# ==============================================================================
# POLICY DOC (data): TerraformProdPolicy
# ------------------------------------------------------------------------------
# WHAT: Permissions policy for TerraformProdRole (CI/CD only)
# PERMISSIONS: Same as before, structured via policy document data source
# ==============================================================================
data "aws_iam_policy_document" "terraform_prod_policy_doc" {
  # CloudFront management
  statement {
    sid     = "CloudFrontManagement"
    effect  = "Allow"
    actions = local.cloudfront_actions
    resources = local.prod_resources.cloudfront_distributions
  }

  # S3 for Terraform state (objects)
  statement {
    sid     = "S3StateObjects"
    effect  = "Allow"
    actions = local.s3_state_object_actions
    resources = local.prod_resources.s3_state_objects
  }

  # S3 for Terraform state (bucket-level)
  statement {
    sid     = "S3StateBucket"
    effect  = "Allow"
    actions = local.s3_state_bucket_actions
    resources = local.prod_resources.s3_state_bucket
  }

  # S3 bucket management for application buckets
  statement {
    sid    = "S3BucketManagement"
    effect = "Allow"
    actions = local.s3_bucket_actions
    resources = local.prod_resources.s3_buckets
  }

  # S3 object operations for application buckets
  statement {
    sid     = "S3ObjectOperations"
    effect  = "Allow"
    actions = local.s3_object_actions
    resources = local.prod_resources.s3_objects
  }

  # DynamoDB table management for application data
  statement {
    sid     = "DynamoDBManagement"
    effect  = "Allow"
    actions = local.dynamodb_actions
    resources = local.prod_resources.dynamodb_tables
  }

  # Route53 & ACM (DNS and certificates)
  statement {
    sid     = "Route53AndACM"
    effect  = "Allow"
    actions = local.route53_acm_actions
    resources = local.prod_resources.route53_acm
  }

  # CloudFormation (SAM deployments)
  statement {
    sid       = "CloudFormationForSAM"
    effect    = "Allow"
    actions   = local.cloudformation_actions
    resources = local.prod_resources.cf_stacks
  }

  # Lambda (SAM deployments)
  statement {
    sid       = "LambdaForSAM"
    effect    = "Allow"
    actions   = local.lambda_actions
    resources = local.prod_resources.lambda_functions
  }

  # API Gateway (SAM deployments)
  statement {
    sid       = "ApiGatewayForSAM"
    effect    = "Allow"
    actions   = local.apigateway_actions
    resources = local.prod_resources.apigw_restapis
  }

  # CloudWatch Logs (Lambda logging)
  statement {
    sid       = "CloudWatchLogs"
    effect    = "Allow"
    actions   = local.logs_actions
    resources = local.prod_resources.logs_groups
  }

  # IAM (read and inline policy ops required by SAM/CFN)
  statement {
    sid       = "IAMOperations"
    effect    = "Allow"
    actions   = local.iam_actions
    resources = local.prod_resources.iam_all
  }

  # Cognito (user pools)
  statement {
    sid       = "CognitoUserPools"
    effect    = "Allow"
    actions   = local.cognito_actions
    resources = local.prod_resources.cognito_userpools
  }
}

resource "aws_iam_policy" "terraform_prod_policy" {
  name   = "TerraformProdPolicy"
  policy = data.aws_iam_policy_document.terraform_prod_policy_doc.json

  tags = local.tags
}

# ==============================================================================
# IAM ROLE: CICDRunnerRole
# ------------------------------------------------------------------------------
# WHAT: Entry point role for GitHub Actions workflows
# WHY: Minimal permissions; assumes environment-specific roles
# NOTE: Behavior preserved; trust uses AssumeRole as in original
# ==============================================================================
resource "aws_iam_role" "cicd_runner" {
  name               = "CICDRunnerRole"
  assume_role_policy = data.aws_iam_policy_document.cicd_runner_trust.json

  tags = local.tags
}

# ==============================================================================
# POLICY DOC (data): CICDRunnerPolicy
# ------------------------------------------------------------------------------
# WHAT: Minimal permissions – can assume Terraform* roles and write logs
# ==============================================================================
data "aws_iam_policy_document" "cicd_runner_policy_doc" {
  # Assume Terraform prod role (dev role currently not in use)
  statement {
    sid     = "AssumeTerraformRoles"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      # aws_iam_role.terraform_dev.arn,  # intentionally commented (unchanged)
      aws_iam_role.terraform_prod.arn
    ]
  }

  # CloudWatch Logs write
  statement {
    sid       = "WriteCloudWatchLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = local.logs_group_arns
  }
}

resource "aws_iam_policy" "cicd_runner_policy" {
  name   = "CICDRunnerPolicy"
  policy = data.aws_iam_policy_document.cicd_runner_policy_doc.json

  tags = local.tags
}

# ==============================================================================
# POLICY ATTACHMENTS: Connect Policies to Roles
# ------------------------------------------------------------------------------
# WHY: Roles and policies are separate resources that must be linked
# ==============================================================================

# resource "aws_iam_role_policy_attachment" "terraform_dev_attach" {
#   role       = aws_iam_role.terraform_dev.name
#   policy_arn = aws_iam_policy.terraform_dev_policy.arn
# }

resource "aws_iam_role_policy_attachment" "terraform_prod_attach" {
  role       = aws_iam_role.terraform_prod.name
  policy_arn = aws_iam_policy.terraform_prod_policy.arn
}

resource "aws_iam_role_policy_attachment" "cicd_runner_attach" {
  role       = aws_iam_role.cicd_runner.name
  policy_arn = aws_iam_policy.cicd_runner_policy.arn
}