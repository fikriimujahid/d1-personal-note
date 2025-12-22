# ===========================================================================
# TERRAFORM CONFIGURATION - Defining AWS Provider Setup
# ===========================================================================
# This block tells Terraform which AWS provider to use and its settings.
# Think of a "provider" as a plugin that lets Terraform talk to a cloud service.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ===========================================================================
# DATA SOURCES - Looking Up Existing AWS Resources
# ===========================================================================
# DATA SOURCES don't create resources; they READ existing ones from AWS.
# Think of them as asking AWS: "Hey, do you have this resource already?"
# This is useful when infrastructure was created outside Terraform or
# by another team - we can reference it without recreating it.

# Route53 Hosted Zone - DNS Service for Your Domain
# Why: We need to add DNS records pointing users to our CloudFront distribution
data "aws_route53_zone" "existing" {
  count        = length(var.domain_aliases) > 0 ? 1 : 0  # Only if custom domains provided
  name         = var.domain_name                          # The domain name (e.g., "example.com")
  private_zone = false                                    # Public DNS (not internal to VPC)
}

# ACM (AWS Certificate Manager) - HTTPS SSL/TLS Certificate
# Why: CloudFront NEEDS a valid HTTPS certificate to serve custom domains securely
# SECURITY: This must be in us-east-1 region - AWS requirement for CloudFront
# LEARNING NOTE: Certificates must be ISSUED (not pending) to be used
data "aws_acm_certificate" "existing" {
  count           = length(var.domain_aliases) > 0 ? 1 : 0  # Only if custom domains
  domain          = var.domain_name
  most_recent     = true                                     # Use the newest cert if multiple exist
  statuses        = ["ISSUED"]                              # Only certificates that are ready
  provider        = aws.us_east_1                           # REQUIRED: Certificates for CloudFront
}

# ===========================================================================
# S3 BUCKET - Static Website Storage
# ===========================================================================
# S3 Bucket - Create Storage Container for Website
# Why: We need somewhere to PUT our website files
# SECURITY: This bucket will be PRIVATE - only CloudFront can read from it
#           (Users access it through CloudFront, not directly)
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name  # Name must be globally unique across all of AWS

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

# S3 Bucket Versioning - Keep File History
# Why: Versioning keeps old versions of files in case you need to restore them
# Use Case: If someone accidentally uploads a bad file, you can rollback
# COST NOTE: Storing multiple versions costs more money
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id  # Reference to S3 bucket created above

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# S3 Bucket Server-Side Encryption - Protect Files at Rest
# Why: Encryption scrambles files so only authorized people can read them
# "At Rest" = Files sitting in storage (not moving over the internet)
# SECURITY: This is CRITICAL for protecting user data and compliance
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm  # Usually "AES256" (SSE-S3) or "aws:kms" (SSE-KMS)
    }
    bucket_key_enabled = true  # Use a bucket key for faster encryption/decryption
  }
}

# S3 Public Access Block - Prevent Accidental Public Exposure
# Why: This is a CRITICAL SECURITY safeguard
# Problem it solves: S3 buckets can accidentally become public (bad!). This resource BLOCKS all public access methods
# SECURITY: Every AWS S3 bucket should have these blocks enabled UNLESS you specifically need public access (and even then, use CloudFront)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true  # Prevent ACL grants that make bucket public
  block_public_policy     = true  # Prevent bucket policies that make it public
  ignore_public_acls      = true  # Ignore existing public ACLs
  restrict_public_buckets = true  # Restrict access even with existing public settings
}

# S3 Bucket Lifecycle Configuration - Automatic Cleanup for Cost Savings
# Why: Storage costs money. Old files should be moved to cheaper storage or deleted
# This configuration handles 3 common scenarios:
#
# 1. INCOMPLETE UPLOADS: Clean up failed multipart uploads (saves money)
# 2. OLD VERSIONS: Move old file versions to cheaper storage (if versioning enabled)
# 3. DELETE MARKERS: Clean up metadata from deleted files
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  # RULE 1: Clean Up Failed Multipart Uploads
  # Why: When large files are uploaded in chunks (multipart), incomplete uploads leave orphaned data that costs money
  rule {
    id     = "cleanup-incomplete-multipart-uploads"
    status = "Enabled"

    filter {} # Apply to all objects (empty filter = everything in bucket)

    abort_incomplete_multipart_upload {
      days_after_initiation = 7  # Delete incomplete uploads older than 7 days
    }
  }

  # RULE 2: Move Old File Versions to Cheaper Storage (if versioning enabled)
  # Why: Saving every version of every file is expensive Old versions are rarely accessed, so move them to cheaper storage
  dynamic "rule" {
    for_each = var.enable_versioning ? [1] : []
    # for_each creates loop: if enable_versioning=true, loop once; if false, don't create
    content {
      id     = "transition-old-versions"
      status = "Enabled"

      filter {} # Apply to all objects

      # Move versions older than 30 days to STANDARD_IA (Infrequent Access)
      # Cost: Cheaper storage BUT costs more per access
      # Good for: Backups, archives, recovery scenarios
      noncurrent_version_transition {
        noncurrent_days = 30
        storage_class   = "STANDARD_IA"
      }

      # Move versions older than 90 days to GLACIER
      # Cost: Much cheaper storage BUT expensive to retrieve
      # Good for: Long-term backup, compliance requirements
      noncurrent_version_transition {
        noncurrent_days = 90
        storage_class   = "GLACIER"
      }

      # Delete versions older than 180 days (6 months)
      # Cost: Free - saves storage costs permanently
      noncurrent_version_expiration {
        noncurrent_days = 180
      }
    }
  }

  # RULE 3: Clean Up Delete Markers
  # Why: When a versioned object is deleted, S3 creates a "delete marker"
  #      When all versions are gone, the marker is outdated and wastes space
  dynamic "rule" {
    for_each = var.enable_versioning ? [1] : []
    content {
      id     = "delete-old-delete-markers"
      status = "Enabled"

      filter {} # Apply to all objects

      expiration {
        expired_object_delete_marker = true  # Delete outdated delete markers
      }
    }
  }
}

# ===========================================================================
# WAFv2 (WEB APPLICATION FIREWALL) - Protect Against Attacks
# ===========================================================================
# WAF = Like a bouncer at a club - blocks malicious requests before they reach your website. Protects against:
# - SQL Injection (attackers trying to access your database)
# - Cross-Site Scripting (XSS) attacks
# - Rate-based attacks (too many requests from one IP)
#
# SECURITY: Highly recommended for any public-facing website. Adds some cost but protects against major attack types

resource "aws_wafv2_web_acl" "cloudfront" {
  count       = var.enable_waf ? 1 : 0  # Only create if WAF is enabled
  provider    = aws.us_east_1  # REQUIRED: CloudFront WAFs must be in us-east-1
  
  name        = "${var.project}-${var.environment}-cloudfront-waf"
  description = "WAF for CloudFront distribution - ${var.environment} environment"
  scope       = "CLOUDFRONT"  # This WAF protects CloudFront (not ALB or API Gateway)

  # DEFAULT ACTION: What to do with requests that don't match any rules
  # "allow" = Let them through (rules below will block bad requests)
  default_action {
    allow {}
  }

  # =========================================================================
  # RULE 1: AWS Managed Core Rule Set
  # =========================================================================
  # What it does: Blocks OWASP Top 10 attacks (industry standard attacks)
  # Includes protections for:
  # - SQL Injection (trying to access databases)
  # - XSS/Cross-Site Scripting (injecting malicious JavaScript)
  # - Local File Inclusion (trying to access system files)
  # - PHP Injection, Java attacks, and more
  #
  # Why AWS Managed: AWS maintains these rules, updating them as new attacks are discovered. You don't have to maintain them.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1  # Priority order: lower numbers evaluated first

    override_action {
      none {}  # Use the rule group's built-in actions (don't override)
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"  # AWS provides this rule set
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true  # Log metrics to CloudWatch for monitoring
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true  # Log sample of matched requests
    }
  }

  # =========================================================================
  # RULE 2: Rate Limiting - Block DDoS Attacks
  # =========================================================================
  # What it does: Blocks IPs that make TOO MANY requests too quickly
  # Protects against: DDoS attacks (overwhelm server with requests)
  # How: If an IP makes > var.waf_rate_limit requests in 5 min = block it
  rule {
    name     = "RateLimitRule"
    priority = 2  # Evaluated second (after Common Rule Set)

    action {
      block {}  # Action when rate limit exceeded: BLOCK the request
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit  # Max requests per IP per 5 min
        aggregate_key_type = "IP"  # Count requests PER IP ADDRESS
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # Overall visibility config for the entire WAF
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CloudFrontWAFMetric"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-cloudfront-waf"
  })
}

# ===========================================================================
# CLOUDFRONT ORIGIN ACCESS CONTROL - Secure S3 Access
# ===========================================================================
# OAC = Origin Access Control (newer, better than OAI)
#
# Why: CloudFront is the ONLY way users access S3
#      Users can't access S3 directly (we block that)
#      OAC signs requests so S3 knows they're from CloudFront
#
# LEARNING NOTE: Signing = Adding a digital signature to prove origin
#                sigv4 = AWS Signature Version 4 (cryptographic signing)
#                Replaces OAI (Origin Access Identity) which is older

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"      # This OAC is for S3
  signing_behavior                  = "always"   # Always sign requests (always use OAC)
  signing_protocol                  = "sigv4"    # Use AWS Signature Version 4
}

# ===========================================================================
# LAMBDA@EDGE - Rewrite Requests at the Edge
# ===========================================================================
# Lambda = AWS's serverless computing (run code without managing servers)
# Lambda@Edge = Run Lambda functions at CloudFront edge locations worldwide
#
# PURPOSE: Rewrite directory requests to index.html
# PROBLEM it solves: Single-page apps (React, Vue, Angular) need
#                    /about → /about/index.html for routing to work
#                    Without this, 404 errors occur
#
# LEARNING NOTE: Serverless = Code runs when needed, scales automatically
#                Edge = Code runs at 400+ locations worldwide (faster)
#                Runtime = Version of programming language (Python 3.12)

# Archive Lambda code into a ZIP file
# Why ZIP: Lambda needs code packaged as ZIP before deployment
# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   output_path = "/tmp/lambda_rewrite.zip"

#   # Embed the Lambda code inline
#   source {
#     content = <<-EOT
# def handler(event, context):
#     # Extract the request from the CloudFront event
#     request = event['Records'][0]['cf']['request']
#     uri = request['uri']
    
#     # REWRITE RULE 1: If URI ends with /, append index.html
#     # Example: /about/ → /about/index.html
#     if uri.endswith('/'):
#         request['uri'] = uri + 'index.html'
    
#     # REWRITE RULE 2: If URI has no extension, append /index.html
#     # Example: /about (no slash, no extension) → /about/index.html
#     # This doesn't match if URI ends with . (like /file.txt)
#     elif '.' not in uri.split('/')[-1]:
#         request['uri'] = uri + '/index.html'
    
#     # Return the (possibly modified) request
#     return request
# EOT
#     filename = "index.py"
#   }
# }

# # IAM Role for Lambda@Edge
# # Why: Lambda needs permission to run and write logs
# #      This role defines what the Lambda function CAN do
# # SECURITY: Following least privilege - only give necessary permissions
# resource "aws_iam_role" "lambda_edge_role" {
#   name = "${var.bucket_name}-lambda-edge-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           # These services CAN assume this role
#           # lambda.amazonaws.com = Regular Lambda
#           # edgelambda.amazonaws.com = Lambda@Edge (CloudFront)
#           Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
#         }
#         Action = "sts:AssumeRole"  # Permission to "use" this role
#       }
#     ]
#   })
# }

# # Attach Basic Lambda Execution Policy
# # Why: Allows Lambda to write logs to CloudWatch (for debugging)
# # SECURITY: Minimal permissions - only logging, nothing else
# resource "aws_iam_role_policy_attachment" "lambda_basic" {
#   role       = aws_iam_role.lambda_edge_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

# # Lambda Function - The Actual Code
# # Why: This is where the request rewriting happens
# # LEARNING NOTE: publish = true means create a VERSION of this Lambda
# #                          (required for Lambda@Edge to use it)
# resource "aws_lambda_function" "cloudfront_rewrite" {
#   provider      = aws.us_east_1  # REQUIRED: Lambda@Edge must be in us-east-1
#   filename      = data.archive_file.lambda_zip.output_path
#   function_name = "${var.bucket_name}-cf-rewrite"
#   role          = aws_iam_role.lambda_edge_role.arn
#   handler       = "index.handler"  # File.function format (index.py, handler function)
#   runtime       = "python3.12"     # Language and version
#   publish       = true             # Create a numbered version (required for Lambda@Edge)

#   source_code_hash = data.archive_file.lambda_zip.output_base64sha256
# }

# ===========================================================================
# CLOUDFRONT DISTRIBUTION - Global Content Delivery
# ===========================================================================
# CloudFront = CDN (Content Delivery Network)
# What it does: Caches your website at servers worldwide so users download from the closest server (faster!)
#
# Benefits:
# 1. SPEED: 400+ locations worldwide = users get served near them
# 2. SECURITY: Built-in DDoS protection, can attach WAF
# 3. SSL/TLS: Automatic HTTPS with valid certificates
# 4. CACHING: Reduces S3 traffic (saves money)
#
# LEARNING NOTE: "Distribution" = Your CloudFront deployment
#                "Origins" = Where content comes from (in our case: S3)

resource "aws_cloudfront_distribution" "website" {
  enabled         = true      # Enable distribution (false would disable it)
  is_ipv6_enabled = true      # Support IPv6 addresses
  comment         = "CloudFront distribution for ${var.bucket_name}"
  default_root_object = var.default_root_object  # Usually "index.html"
  price_class     = var.price_class  # Cost optimization: which edge locations to use
                                     # PriceClass_100 = cheapest (fewer locations)
                                     # PriceClass_All = all locations (most expensive)

  aliases = var.domain_aliases  # Custom domain names (e.g., "example.com")

  # =========================================================================
  # ORIGIN: Where content comes from
  # =========================================================================
  # CloudFront needs to know: "Where should I get the files?"
  # In our case: S3 bucket
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    # SECURITY: Only CloudFront can access S3 (via OAC signing)
  }

  # =========================================================================
  # DEFAULT CACHE BEHAVIOR: How to handle requests
  # =========================================================================
  default_cache_behavior {
    # ALLOWED METHODS: What HTTP verbs should be processed
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    # GET = download files
    # HEAD = download metadata (for testing)
    # OPTIONS = CORS preflight requests
    # We DON'T allow POST/PUT/DELETE (this is read-only)

    cached_methods = ["GET", "HEAD"]  # Only cache GET and HEAD
                                      # OPTIONS responses change, don't cache them

    target_origin_id = "S3-${aws_s3_bucket.website.id}"
    compress         = true  # Compress files (gzip) to reduce bandwidth
                             # Saves money and speeds up users
    viewer_protocol_policy = "redirect-to-https"
    # SECURITY: Always use HTTPS
    # redirect-to-https = HTTP requests automatically → HTTPS

    # Cache Policy: AWS Managed cache strategy
    # "CachingOptimized" = Cache responses for best performance
    # 4135ea2d-6df8-44a3-9df3-4b5a84be39ad is the ID for CachingOptimized
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # Lambda@Edge Function: Rewrite directory requests
    # Event: origin-request = when CloudFront requests file from S3
    # This runs BEFORE the request reaches S3
    # lambda_function_association {
    #   event_type   = "origin-request"
    #   lambda_arn   = aws_lambda_function.cloudfront_rewrite.qualified_arn
    #   include_body = false  # Don't send request body to Lambda (no need)
    # }
  }

  # =========================================================================
  # CUSTOM ERROR RESPONSES: Handle 404 and other errors gracefully
  # =========================================================================
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
    }
  }

  # =========================================================================
  # GEOGRAPHIC RESTRICTIONS: Block/allow countries (optional)
  # =========================================================================
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type != null ? var.geo_restriction_type : "none"
      locations        = var.geo_restriction_type != null ? var.geo_restriction_locations : []
    }
  }

  # =========================================================================
  # SSL/TLS CERTIFICATE: HTTPS configuration
  # =========================================================================
  # LEARNING NOTE: Two scenarios:
  # 1. Custom domain (example.com): Use ACM certificate
  # 2. Default domain (d123.cloudfront.net): Use CloudFront cert
  #
  # SECURITY: All served via HTTPS (TLS 1.2 minimum)
  viewer_certificate {
    # If custom domains provided: use ACM certificate (we looked it up earlier)
    acm_certificate_arn      = length(var.domain_aliases) > 0 ? data.aws_acm_certificate.existing[0].arn : null
    # If no custom domains: use CloudFront default certificate
    cloudfront_default_certificate = length(var.domain_aliases) == 0 ? true : null
    # SNI Only = CloudFront uses Server Name Indication (modern, efficient)
    ssl_support_method       = length(var.domain_aliases) > 0 ? "sni-only" : null
    # Minimum TLS 1.2 = Don't support older, insecure versions
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # =========================================================================
  # LOGGING: Record who accesses your website (optional)
  # =========================================================================
  # LEARNING NOTE: dynamic block creates logging only if enabled
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      bucket          = var.logging_bucket  # S3 bucket to store access logs
      prefix          = var.logging_prefix  # Folder prefix (e.g., "cloudfront-logs/")
      include_cookies = false  # Don't log cookies (privacy)
    }
  }

  # =========================================================================
  # WAF WEB ACL: Attach WAF for security
  # =========================================================================
  # LEARNING NOTE: Conditional attachment based on var.enable_waf
  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.cloudfront[0].arn : var.web_acl_id
  # If WAF enabled: use the one we created
  # If WAF disabled: use var.web_acl_id (could be null or external WAF)

  tags = merge(var.tags, {
    Name = "${var.bucket_name}-cloudfront"
  })
}

# ===========================================================================
# S3 BUCKET POLICY - CloudFront Permission to Read S3
# ===========================================================================
# Policy = Permission document (JSON)
# What it says: "CloudFront (and ONLY CloudFront) can read files from S3"
#
# SECURITY: This is the key to keeping S3 private while allowing CloudFront
#           through. Users can't access S3 directly - they go through
#           CloudFront, which uses this policy to read files.
#
# LEARNING NOTE: Principal = Who gets permission
#                Action = What they can do
#                Resource = What they can do it to
#                Condition = When the permission applies

resource "aws_s3_bucket_policy" "cloudfront_oac" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"  # Only CloudFront service
        }
        Action   = "s3:GetObject"  # Only READ permission (not write, delete, etc.)
        Resource = "${aws_s3_bucket.website.arn}/*"  # All objects in bucket
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
            # SECURITY: Only THIS specific CloudFront distribution
            #           Not CloudFront in general, not other distributions
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.website,
    aws_cloudfront_origin_access_control.website
  ]
}

# ===========================================================================
# DNS RECORDS - Connect Domain Names to CloudFront
# ===========================================================================
# DNS = Domain Name System (translates example.com → IP address)
# Route53 = AWS's DNS service
#
# What this does: Creates A records that point your domain names to CloudFront
# Example: When user types "example.com", DNS says:
#          "Go to CloudFront distribution d123.cloudfront.net"
#          CloudFront then serves your S3 website
#
# LEARNING NOTE: A Record = Maps domain name to IP address
#                ALIAS = AWS extension of A records (can point to AWS services)
#                        Regular A records point to IP addresses
#                        ALIAS records point to AWS services (which have IPs)

# Create A record for EACH custom domain in var.domain_aliases
resource "aws_route53_record" "cloudfront_a" {
  for_each = toset(var.domain_aliases)

  zone_id = data.aws_route53_zone.existing[0].zone_id  # Our Route53 zone
  name    = each.value  # The domain name (e.g., "example.com" or "www.example.com")
  type    = "A"         # A record type

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    # CloudFront gives us a domain like: d123.cloudfront.net
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    # Each service has a zone_id (CloudFront's zone_id)
    evaluate_target_health = false
    # false = don't check if CloudFront is healthy before responding
    # (CloudFront is so reliable, this isn't necessary)
  }
}
