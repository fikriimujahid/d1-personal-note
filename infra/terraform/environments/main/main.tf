# ============================================================================
# Terraform Configuration
# ----------------------------------------------------------------------------
# This block configures Terraform itself:
# - required_version: Ensures you're using a compatible Terraform CLI.
# - required_providers: Declares which providers (e.g., AWS) this config needs
#   and their allowed versions for stability.
# - backend "s3": Moves Terraform state off your local machine into an S3
#   bucket (configured via backend.hcl) for team safety, locking, and recovery.
#
# Why remote state? Local state is risky (loss/corruption). S3 + DynamoDB (if
# configured in backend.hcl) provides locking and robustness.
# ============================================================================

terraform {
  required_version = ">= 1.0" # Use Terraform v1+ for current syntax/features

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Stick to AWS provider v5.x to avoid breaking changes
    }
  }

  backend "s3" {
    # Configuration loaded from backend.hcl
    # Beginner tip: backend is not a resource; it's how Terraform stores its
    # state. You usually set bucket, key, region, and DynamoDB table here via
    # backend.hcl so credentials/paths aren't hardcoded in this file.
  }
}

# ============================================================================
# Provider Configuration
# ----------------------------------------------------------------------------
# Providers are plugins that let Terraform talk to cloud APIs.
# We configure the default AWS provider with a region and default tags.
# Default tags help consistently label all resources for cost and ops visibility.
# ============================================================================
provider "aws" {
  region = var.aws_region # Set in variables.tf and terraform.tfvars

  default_tags {
    tags = {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    }
  }
}

# ----------------------------------------------------------------------------
# Secondary AWS provider alias (us-east-1)
# Some AWS services require the "us-east-1" region regardless of your main
# region. Common examples: CloudFront (global), ACM certs for CloudFront,
# and AWS WAF. We define an alias to target those resources explicitly.
# ----------------------------------------------------------------------------
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ============================================================================
# Variables vs Locals
# ----------------------------------------------------------------------------
# - Variables (var.*) are external inputs, typically provided via
#   environments/main/terraform.tfvars or -var flags at runtime.
# - Locals are computed values used for readability and consistency.
# Here we centralize standard tags so modules/resources get uniform labeling.
# ============================================================================

locals {
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ============================================================================
# IAM Module
# ----------------------------------------------------------------------------
# Purpose: Centralize account-wide IAM roles/policies needed by this project.
# Service: AWS IAM.
# Security: Least privilege is key. Keep policies scoped to exactly what
# services need. Avoid wildcard actions/resources where possible.
# Ordering: IAM roles are typically safe to create early; other modules may
# depend on them indirectly.
# ============================================================================

module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
}

# ============================================================================
# Database Module (DynamoDB)
# ----------------------------------------------------------------------------
# Purpose: Provision DynamoDB tables for application data.
# Service: Amazon DynamoDB.
# Security: Prefer server-side encryption (SSE) and restrictive IAM policies
# for access. Review table capacity, PITR (point-in-time recovery), and TTL
# in the module implementation.
# Maintainability: Tables are passed in via variables for clear, declarative
# configuration.
# ============================================================================

module "database" {
  source = "../../modules/dynamodb"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
  tables      = var.tables # Define table names/attributes in variables.tf/terraform.tfvars
}

# ============================================================================
# Auth Module
# ----------------------------------------------------------------------------
# Purpose: Provide user authentication/authorization (often via Cognito).
# Service: Typically Amazon Cognito User Pools/Identity Pools.
# Security: Strong password policies, MFA, secure app clients, and careful
# callback URLs are common considerations. Review the module for exact resources.
# ============================================================================

module "auth" {
  source = "../../modules/auth"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}

# ============================================================================
# Hosting Module (Static Web + CDN + WAF)
# ----------------------------------------------------------------------------
# Purpose: Host a static frontend backed by S3, accelerated by CloudFront,
# secured with ACM TLS certs in us-east-1, optionally protected by WAF.
# Services: S3 (origin), CloudFront (CDN), ACM (cert), Route 53 (if used), WAF.
# Security:
# - Encryption at rest: S3 SSE via sse_algorithm.
# - Encryption in transit: CloudFront + ACM certs.
# - Logging: Access logs to a dedicated bucket/prefix.
# - WAF: Mitigate common web attacks and rate-limit abusive traffic.
# Dependencies: ACM + CloudFront require us-east-1 provider alias.
# Beginner tip: Keep origin private when possible and serve via CloudFront.
# ============================================================================
module "hosting" {
  source = "../../modules/hosting"

  # Use specific providers: default for your main region, us-east-1 for
  # global/edge services like CloudFront/ACM/WAF.
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  # Consistent metadata across resources
  project     = var.project
  environment = var.environment
  tags        = local.common_tags

  # ----------------------
  # S3 Origin Configuration
  # ----------------------
  # bucket_name: Name of the S3 bucket hosting static assets.
  # enable_versioning: Keeps object versions for safer rollbacks.
  # sse_algorithm: Server-side encryption (e.g., AES256 or aws:kms).
  bucket_name       = var.bucket_name
  enable_versioning = var.enable_versioning
  sse_algorithm     = var.sse_algorithm

  # ----------------------
  # Domains / CloudFront
  # ----------------------
  # domain_name: Primary domain served by CloudFront.
  # domain_aliases: Additional CNAMEs (e.g., www.example.com).
  # default_root_object: Entry point file (index.html) for single-page apps.
  # price_class: Limits edge locations to control cost (e.g., PriceClass_100).
  # geo_restriction_*: Optional allow/deny lists by country for compliance.
  domain_name               = var.domain_name
  domain_aliases            = var.domain_aliases
  default_root_object       = var.default_root_object
  price_class               = var.price_class
  geo_restriction_type      = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations

  # ----------------------
  # Logging
  # ----------------------
  # enable_logging: Turn on access logs for auditing/troubleshooting.
  # logging_bucket: Separate bucket to store logs (avoid mixing with origin).
  # logging_prefix: Path prefix to organize logs.
  enable_logging = var.enable_logging
  logging_bucket = var.logging_bucket
  logging_prefix = var.logging_prefix

  # ----------------------
  # WAF (Web Application Firewall)
  # ----------------------
  # enable_waf: Whether to attach a Web ACL to CloudFront.
  # waf_rate_limit: Basic rate limiting to throttle abusive IPs.
  # web_acl_id: Use an existing Web ACL ID when not creating one in-module.
  enable_waf     = var.enable_waf
  waf_rate_limit = var.waf_rate_limit
  web_acl_id     = var.web_acl_id
}