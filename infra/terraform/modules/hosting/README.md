# Hosting Module (S3 + CloudFront)

A beginner-friendly guide to deploying a secure, global static website using Amazon S3 (storage) and CloudFront (CDN), with optional Route53 DNS, ACM certificates, AWS WAF, and Lambda@Edge for SPA routing.

---

## What This Module Does
- Creates a private S3 bucket to store your static website files
- Serves your site globally via CloudFront (CDN) for performance and security
- Optionally adds custom domains via Route53 + ACM
- Optionally protects the site with AWS WAF managed rules and rate limiting
- Optionally rewrites requests with Lambda@Edge for single-page apps (SPA)
- Adds secure bucket policy so only CloudFront can read from S3 (via OAC)

---

## High-Level Architecture
```
[Users Worldwide]
      |
   HTTPS
      |
[Amazon CloudFront]  --(Lambda@Edge: rewrite / → /index.html)-->  [Private S3 Bucket]
      |
   (optional)
      +--> [AWS WAF] (blocks attacks)
      +--> [Route53 A/ALIAS records for custom domains]
      +--> [ACM cert in us-east-1 for HTTPS on custom domains]
```

---

## Prerequisites
- AWS account and credentials configured for Terraform
- Optional (custom domains):
  - A public Route53 hosted zone for your `domain_name`
  - An ACM certificate in `us-east-1` for your domain and aliases
- IAM permissions to manage S3, CloudFront, ACM (read-only), Route53 (optional), WAF (optional), and Lambda

---

## Providers
- Uses the `hashicorp/aws` provider.
- Uses a provider alias `aws.us_east_1` for resources that must live in `us-east-1` (CloudFront WAF, ACM cert lookups, Lambda@Edge).

---

## Inputs (Variables)
- `project` (string): Project name; used in naming/tagging.
- `environment` (string): Environment name (e.g., `dev`, `staging`, `prod`).
- `tags` (map(string)): Tags merged into all resources.

- `domain_name` (string|null): Root domain (e.g., `example.com`). Required only when using `domain_aliases`.
- `domain_aliases` (list(string)): Custom hostnames for CloudFront (e.g., `example.com`, `www.example.com`). Optional.

- `bucket_name` (string): Globally unique S3 bucket name to host the website.
- `enable_versioning` (bool): Keep old versions of files for rollback. Default: `true`.
- `sse_algorithm` (string): Server-side encryption algorithm (`AES256` or `aws:kms`). Default: `AES256`.

- `default_root_object` (string): Root object served at `/` (typically `index.html`). Default: `index.html`.
- `price_class` (string): CloudFront price class (`PriceClass_All`, `PriceClass_200`, `PriceClass_100`). Default: `PriceClass_100`.
- `custom_error_responses` (list(object)): Error mappings (e.g., map 403/404 to `/index.html` for SPAs).
- `geo_restriction_type` (string|null): `whitelist`, `blacklist`, or `none` (default `none` when null).
- `geo_restriction_locations` (list(string)): ISO country codes when using geo restrictions.

- `enable_waf` (bool): Attach WAF to CloudFront. Default: `false`.
- `waf_rate_limit` (number): Rate limit per IP per 5 minutes. Default: `1000`.
- `web_acl_id` (string|null): Use an existing WAF Web ACL when `enable_waf = false`.

- `enable_logging` (bool): Enable CloudFront access logging. Default: `false`.
- `logging_bucket` (string|null): S3 bucket name for logs (required when `enable_logging = true`).
- `logging_prefix` (string): Prefix for CloudFront logs, should end with `/`. Default: `cloudfront-logs/`.

---

## Outputs
- `bucket_name`: Name (ID) of the website S3 bucket.
- `cloudfront_distribution_id`: CloudFront distribution ID.
- `cloudfront_domain_name`: CloudFront distribution domain (e.g., `d123.cloudfront.net`).
- `route53_record_names`: List of Route53 record names created for aliases (if any).

---

## Usage Example
```hcl
module "hosting" {
  source = "./infra/terraform/modules/hosting"

  project     = "demo"
  environment = "dev"

  tags = {
    Owner      = "team-web"
    Environment= "dev"
  }

  # S3
  bucket_name       = "demo-dev-website-bucket-12345"
  enable_versioning = true
  sse_algorithm     = "AES256"

  # CloudFront
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  # Domains (optional)
  domain_name    = "example.com"
  domain_aliases = ["example.com", "www.example.com"]

  # Errors for SPA routing
  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 404
      response_page_path = "/index.html"
    },
    {
      error_code         = 403
      response_code      = 404
      response_page_path = "/index.html"
    }
  ]

  # Geo restrictions (optional)
  geo_restriction_type      = null
  geo_restriction_locations = []

  # WAF (optional)
  enable_waf     = true
  waf_rate_limit = 1000

  # Logging (optional)
  enable_logging  = true
  logging_bucket  = "demo-dev-cf-logs-bucket-12345"
  logging_prefix  = "cloudfront-logs/"
}
```

---

## How It Works
1. **S3 Bucket**
   - Private by default (public access blocks enabled)
   - Server-side encryption enabled (`AES256` by default)
   - Optional versioning and lifecycle rules to reduce costs
2. **CloudFront Distribution**
   - Points to the S3 bucket as the origin
   - Enforces HTTPS and caches content globally
   - Uses an AWS managed cache policy (CachingOptimized)
3. **Origin Access Control (OAC)**
   - CloudFront signs requests to S3 so the bucket can remain private
4. **Bucket Policy**
   - Grants `s3:GetObject` to CloudFront only (scoped to this distribution via SourceArn)
5. **Lambda@Edge (optional)**
   - Rewrites requests like `/about` → `/about/index.html` for SPA routing
6. **WAF (optional)**
   - Attaches managed AWS rules and rate limiting to block common attacks
7. **Route53 + ACM (optional)**
   - Creates A/ALIAS records for each `domain_aliases` entry
   - Uses an **ISSUED** ACM certificate in `us-east-1` for HTTPS on custom domains

---

## Security Notes
- **S3 privacy**: The bucket is not publicly accessible; only CloudFront can read via OAC.
- **Encryption at rest**: Enabled for S3. Consider `aws:kms` for stricter key control.
- **HTTPS**: CloudFront enforces modern TLS (`TLSv1.2_2021`).
- **WAF**: Strongly recommended for production; blocks OWASP Top 10 and rate-based abuse.
- **Logging**: Prefer logs in a dedicated bucket; avoid logging cookies unless required.

---

## Trade-Offs & Alternatives
- **Price Class**: `PriceClass_100` saves cost but reduces edge locations; use `200` or `All` for broader reach.
- **Encryption**: `AES256` is simpler; `aws:kms` offers finer control with additional cost/complexity.
- **SPA routing**: Lambda@Edge is powerful; for simpler sites, omit it and serve direct paths.

---

## Common Beginner Mistakes
- Using custom domains without an ACM certificate in `us-east-1`.
- Forgetting to set `logging_bucket` when `enable_logging = true`.
- Assuming S3 is public — it is private; upload via CI and serve through CloudFront.
- Mis-typing `price_class`; must be one of `PriceClass_All`, `PriceClass_200`, `PriceClass_100`.

---

## Deployment
```bash
# From your Terraform root
terraform init
terraform plan -var-file=infra/terraform/environments/main/terraform.tfvars
terraform apply -var-file=infra/terraform/environments/main/terraform.tfvars
```

---

## Troubleshooting
- **Certificate Not Found**: Ensure ACM cert for `domain_name`/aliases is ISSUED in `us-east-1`.
- **DNS Not Resolving**: Verify Route53 hosted zone matches `domain_name` and records exist.
- **403/404 for SPA**: Confirm Lambda@Edge rewrite is published and associated; check `custom_error_responses`.
- **Access Denied from S3**: Check bucket policy and CloudFront OAC; users should never access S3 directly.

---

## Cleaning Up
```bash
terraform destroy -var-file=infra/terraform/environments/main/terraform.tfvars
```
