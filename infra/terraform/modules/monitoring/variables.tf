# ============================================================================
# Terraform Module: Monitoring - Variables
# ============================================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/main)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# SNS Configuration
# ============================================================================

variable "critical_notification_emails" {
  description = "Email addresses for critical incident notifications (P0/P1)"
  type        = list(string)
}

variable "warning_notification_emails" {
  description = "Email addresses for warning incident notifications (P2/P3)"
  type        = list(string)
}

# ============================================================================
# Service-Specific Configuration
# ============================================================================

variable "api_name" {
  description = "Name of the API Gateway API"
  type        = string
}

variable "lambda_function_names" {
  description = "List of Lambda function names to create individual alarms for"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_names" {
  description = "List of DynamoDB table names to monitor"
  type        = list(string)
  default     = []
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID to monitor"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID to monitor"
  type        = string
  default     = ""
}

# ============================================================================
# Encryption
# ============================================================================

variable "kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs encryption (optional)"
  type        = string
  default     = null
}
