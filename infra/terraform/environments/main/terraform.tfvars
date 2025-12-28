# ============================================================================
# Common Configuration
# ============================================================================

project     = "d1-personal-note"
environment = "main"
aws_region  = "ap-southeast-1"

# ============================================================================
# Database Module Configuration
# ============================================================================

tables = {
  notes = {
    billing_mode = "PAY_PER_REQUEST"
    table_class  = "STANDARD_INFREQUENT_ACCESS"
    hash_key     = "pk"
    range_key    = "sk"
    attributes = [
      { name = "pk", type = "S" },
      { name = "sk", type = "S" }
    ]
    deletion_protection_enabled    = false
    point_in_time_recovery_enabled = false # Enable for disaster recovery (RPO: 5 min, 35-day retention)
    ttl_attribute                  = "ttl"
    on_demand_throughput = {
      max_read_request_units  = 2
      max_write_request_units = 2
    }
  }
}

# ============================================================================
# Auth Module Configuration
# ============================================================================

cognito_tier             = "LITE"
password_min_length      = 12
enable_mfa               = false
enable_advanced_security = false

# ============================================================================
# Hosting Module Configuration
# ============================================================================

# S3
bucket_name       = "d1-personal-note-main-website"
enable_versioning = true
sse_algorithm     = "AES256"

# CloudFront & Domains
domain_name         = "fikri.dev"
domain_aliases      = ["d1.fikri.dev"]
price_class         = "PriceClass_100"
default_root_object = "index.html"

# WAF (disabled by default in dev)
enable_waf     = false
waf_rate_limit = 100
web_acl_id     = null

# Geo restrictions (optional)
geo_restriction_type      = null
geo_restriction_locations = []

# Logging (optional)
enable_logging = false
logging_bucket = null
logging_prefix = "cloudfront-logs/"

# ============================================================================
# Monitoring Module Configuration
# ============================================================================

critical_notification_emails = ["alert@fikri.dev"]
warning_notification_emails  = ["alert@fikri.dev"]

# ============================================================================
# Budget Module Configuration
# ============================================================================

budget_limit               = "10"
budget_notification_emails = ["alert@fikri.dev"]
