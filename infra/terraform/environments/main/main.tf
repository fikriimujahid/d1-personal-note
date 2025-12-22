# ============================================================================
# Terraform Configuration
# ============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configuration loaded from backend.hcl
  }
}

# ============================================================================
# Provider Configuration 
# ============================================================================

provider "aws" {
  region  = var.aws_region

  default_tags {
    tags = {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    }
  }
}

# Additional provider alias for us-east-1 (required by CloudFront/ACM/WAF)
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
}

# ============================================================================
# Local Values 
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
# ============================================================================

module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
}

# ============================================================================
# Database Module
# ============================================================================

module "database" {
  source = "../../modules/dynamodb"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
  tables      = var.tables
}

# ============================================================================
# Auth Module
# ============================================================================

module "auth" {
  source = "../../modules/auth"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}

# ============================================================================
# Hosting Module
# ============================================================================
module "hosting" {
  source = "../../modules/hosting"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project     = var.project
  environment = var.environment
  tags        = local.common_tags

  # S3
  bucket_name       = var.bucket_name
  enable_versioning = var.enable_versioning
  sse_algorithm     = var.sse_algorithm

  # Domains / CloudFront
  domain_name               = var.domain_name
  domain_aliases            = var.domain_aliases
  default_root_object       = var.default_root_object
  price_class               = var.price_class
  geo_restriction_type      = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations

  # Logging
  enable_logging = var.enable_logging
  logging_bucket = var.logging_bucket
  logging_prefix = var.logging_prefix

  # WAF
  enable_waf     = var.enable_waf
  waf_rate_limit = var.waf_rate_limit
  web_acl_id     = var.web_acl_id
}