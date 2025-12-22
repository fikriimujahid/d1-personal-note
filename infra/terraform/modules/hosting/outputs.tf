# =============================================================================
# S3 Website Hosting Outputs
# =============================================================================

output "bucket_name" {
  description = "Name of the website S3 bucket"
  value       = aws_s3_bucket.website.id
}

# =============================================================================
# CloudFront Outputs
# =============================================================================

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.domain_name
}

# Route53 records created for each alias (if any)
output "route53_record_names" {
  description = "List of Route53 record names created for CloudFront aliases"
  value       = keys(aws_route53_record.cloudfront_a)
}