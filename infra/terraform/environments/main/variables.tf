# ============================================================================
# Common Variables
# ============================================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# ============================================================================
# Database Module Variables
# ============================================================================

variable "tables" {
  description = "Map of DynamoDB tables to create for this environment"
  type        = map(any)
  default     = {}
}

# ============================================================================
# Auth Module Variables
# ============================================================================

variable "cognito_tier" {
  description = "Cognito User Pool Tier (LITE or PLUS)"
  type        = string
  default     = "LITE"
}

variable "password_min_length" {
  description = "Minimum password length"
  type        = number
  default     = 12
}

variable "enable_mfa" {
  description = "Enable MFA"
  type        = bool
  default     = false
}

variable "enable_advanced_security" {
  description = "Enable Advanced Security Features (Audit/Enforced)"
  type        = bool
  default     = false
}

variable "callback_urls" {
  description = "List of allowed callback URLs"
  type        = list(string)
  default     = ["http://localhost:3000/api/auth/callback/cognito"]
}

variable "logout_urls" {
  description = "List of allowed logout URLs"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

# ============================================================================
# Hosting Module Variables
# ============================================================================

variable "bucket_name" {
  description = "Name of the S3 bucket for static website hosting"
  type        = string
}

variable "domain_name" {
  description = "Root domain (optional when no custom aliases)"
  type        = string
  default     = null
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "SSE algorithm for S3 (AES256 or aws:kms)"
  type        = string
  default     = "AES256"
}

variable "enable_waf" {
  description = "Enable WAF for CloudFront"
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes)"
  type        = number
  default     = 1000
}

variable "web_acl_id" {
  description = "Existing WAF Web ACL ID (used when enable_waf is false)"
  type        = string
  default     = null
}

variable "default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "domain_aliases" {
  description = "Custom domain aliases for CloudFront"
  type        = list(string)
  default     = []
}

variable "geo_restriction_type" {
  description = "Geo restriction type (whitelist, blacklist, none)"
  type        = string
  default     = null
}

variable "geo_restriction_locations" {
  description = "Geo restriction locations"
  type        = list(string)
  default     = []
}

variable "enable_logging" {
  description = "Enable CloudFront logging"
  type        = bool
  default     = false
}

variable "logging_bucket" {
  description = "S3 bucket for CloudFront logs"
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for CloudFront logs"
  type        = string
  default     = "cloudfront-logs/"
}