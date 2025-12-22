# ============================================================================
# IAM Module Outputs
# ============================================================================

output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

output "cognito_service_role_arn" {
  description = "ARN of Cognito service role"
  value       = module.iam.cognito_service_role_arn
}

# ============================================================================
# Database Module Outputs
# ============================================================================

output "table_name" {
  description = "Name of the DynamoDB table"
  value       = module.database.table_name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.database.table_arn
}

# ============================================================================
# Auth Module Outputs
# ============================================================================

output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.auth.user_pool_id
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = module.auth.user_pool_client_id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = module.auth.user_pool_arn
}

# ============================================================================
# Hosting Module Outputs 
# ============================================================================

output "hosting_bucket_name" {
  description = "Name of the website S3 bucket"
  value       = module.hosting.bucket_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.hosting.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.hosting.cloudfront_domain_name
}