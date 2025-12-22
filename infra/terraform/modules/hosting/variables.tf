# =============================================================================
# Module Inputs (Terraform Variables)
# =============================================================================
# BEGINNER NOTES:
# - Variables are inputs to this module — like function parameters.
# - They do NOT create resources; they only pass values into resources.
# - Keep values simple and explicit for readability.
# - Security-related inputs are highlighted with notes and guardrails.

# =============================================================================
# Common Variables
# =============================================================================

variable "project" {
  description = "Project name. Used for naming and tagging resources to group them by application."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod). Helps separate and isolate deployments."
  type        = string
}

variable "tags" {
  description = "Resource tags for cost, ownership, and environment tracking. These are merged onto all resources."
  type        = map(string)
  default     = {}
}

# =============================================================================
# Domain & DNS
# =============================================================================

variable "domain_name" {
  description = "Root domain name (e.g., example.com). Optional when no domain aliases are set."
  type        = string
  default     = null

  # LEARNING NOTE:
  # - Custom domains require a Route53 hosted zone and an ACM certificate in us-east-1.
  # - When using domain aliases, domain_name should match the hosted zone and certificate.
  validation {
    condition     = var.domain_name == null || can(regex("^[A-Za-z0-9.-]+$", var.domain_name))
    error_message = "domain_name must be a valid DNS name (letters, numbers, dots, and hyphens) or null."
  }
}

# =============================================================================
# S3 Website Hosting
# =============================================================================

variable "bucket_name" {
  description = "Name of the S3 bucket for static website hosting. Must be globally unique across AWS."
  type        = string

  # SECURITY NOTE:
  # - S3 bucket names are globally unique; choose deterministic names per project+environment.
  # - Bucket access is private; CloudFront reads via Origin Access Control.
  validation {
    condition     = length(var.bucket_name) > 0
    error_message = "bucket_name cannot be empty."
  }
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning (helps rollback, increases storage cost)."
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm (AES256 or aws:kms)."
  type        = string
  default     = "AES256"

  # SECURITY NOTE:
  # - AES256 = SSE-S3 (AWS-managed keys, simpler)
  # - aws:kms = SSE-KMS (customer-managed keys, more control, potentially more cost)
  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be either 'AES256' or 'aws:kms'."
  }
}

# =============================================================================
# Web Application Firewall (WAF)
# =============================================================================

variable "enable_waf" {
  description = "Enable WAF for CloudFront to block common attacks and rate abuse."
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5-minute period per IP)."
  type        = number
  default     = 1000

  # RATE LIMIT NOTE:
  # - Requests per 5-minute window per IP. Higher values allow more traffic before blocking.
  validation {
    condition     = var.waf_rate_limit >= 100
    error_message = "waf_rate_limit must be at least 100 requests per 5 minutes."
  }
}

# If WAF is managed outside this module, provide an existing Web ACL ID
variable "web_acl_id" {
  description = "WAF Web ACL ID for CloudFront (optional - used if enable_waf is false)"
  type        = string
  default     = null
}

# =============================================================================
# CloudFront Distribution
# =============================================================================

variable "default_root_object" {
  description = "Default root object for CloudFront (e.g., index.html)."
  type        = string
  default     = "index.html"

  # ROUTING NOTE:
  # - The default file CloudFront serves at the root path. For SPAs, typically 'index.html'.
  validation {
    condition     = length(var.default_root_object) > 0
    error_message = "default_root_object cannot be empty."
  }
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)."
  type        = string
  default     = "PriceClass_100" # Cost optimization: only US, Canada, Europe

  # COST NOTE:
  # - PriceClass_100: Least expensive (US/Canada/Europe)
  # - PriceClass_200: More edge locations
  # - PriceClass_All: All locations (most expensive)
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "price_class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "domain_aliases" {
  description = "List of domain aliases for CloudFront (e.g., [example.com, www.example.com])"
  type        = list(string)
  default     = []
}

variable "custom_error_responses" {
  description = "Custom error responses for CloudFront (useful for SPAs to route 403/404 to index.html)."
  type = list(object({
    error_code         = number
    response_code      = number
    response_page_path = string
  }))
  default = [
    {
      error_code         = 404
      response_code      = 404
      response_page_path = "/index.html" # SPA fallback
    },
    {
      error_code         = 403
      response_code      = 404
      response_page_path = "/index.html"
    }
  ]
}

variable "geo_restriction_type" {
  description = "Geo restriction type (whitelist, blacklist, none)."
  type        = string
  default     = null

  # GEO NOTE:
  # - whitelist: only allow specified countries
  # - blacklist: block specified countries
  # - none: allow all (most common)
  validation {
    condition     = var.geo_restriction_type == null || contains(["whitelist", "blacklist", "none"], var.geo_restriction_type)
    error_message = "geo_restriction_type must be null or one of: whitelist, blacklist, none."
  }
}

variable "geo_restriction_locations" {
  description = "List of ISO country codes for geo restrictions (e.g., ['US', 'CA'])."
  type        = list(string)
  default     = []
}

# =============================================================================
# Logging
# =============================================================================

variable "enable_logging" {
  description = "Enable CloudFront access logging."
  type        = bool
  default     = false
}

variable "logging_bucket" {
  description = "S3 bucket name for CloudFront logs (required when enable_logging is true)."
  type        = string
  default     = null

  # PRIVACY + OPERATIONS NOTE:
  # - Access logs are useful for troubleshooting and analytics.
  # - Consider privacy: do not log cookies unless necessary.
  validation {
    condition     = var.enable_logging == false || (var.enable_logging == true && var.logging_bucket != null)
    error_message = "logging_bucket must be set (non-null) when enable_logging is true."
  }
}

variable "logging_prefix" {
  description = "Prefix (folder path) for CloudFront log files (should end with '/')."
  type        = string
  default     = "cloudfront-logs/"

  validation {
    condition     = can(regex(".*/$", var.logging_prefix))
    error_message = "logging_prefix should end with a '/'."
  }
}
