### Output Values for IAM Module
# Purpose: Expose resource identifiers that other modules or resources need to reference.

# TERRAFORM CONCEPT: Outputs are the "return values" of a module.
# They make internal resource attributes accessible to:
# - Other modules that call this module
# - Root module outputs (shown after terraform apply)
# - Other resources that depend on these values

# ============================================================================
# OUTPUT: lambda_execution_role_arn
# ----------------------------------------------------------------------------
# What: Amazon Resource Name (ARN) of the Lambda execution role.
# Why: Lambda functions need this ARN to specify which role they'll assume.
# Used by: Lambda function configurations (aws_lambda_function.role)
# Format: arn:aws:iam::123456789012:role/myapp-lambda-execution-dev
output "lambda_execution_role_arn" {
  description = "ARN of the IAM role for Lambda function execution. Pass this to aws_lambda_function.role to grant Lambda the necessary permissions."
  value       = aws_iam_role.lambda_execution_role.arn

  # TERRAFORM CONCEPT: This creates an implicit dependency.
  # Any resource using this output will wait for the role to be created.
}

# ============================================================================
# OUTPUT: lambda_execution_role_name
# ----------------------------------------------------------------------------
# What: Human-readable name of the Lambda execution role.
# Why: Useful for IAM policy references, CloudWatch log filtering, and debugging.
# Used by: IAM policies, AWS CLI commands, documentation.
output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role. Useful for IAM policy references and AWS CLI operations."
  value       = aws_iam_role.lambda_execution_role.name
}

# ============================================================================
# OUTPUT: cognito_service_role_arn
# ----------------------------------------------------------------------------
# What: Amazon Resource Name (ARN) of the Cognito service role.
# Why: Cognito needs this ARN for features like SMS MFA (sending texts via SNS).
# Used by: Cognito User Pool SMS configuration.
# Note: Currently unused but available for future Cognito features.
output "cognito_service_role_arn" {
  description = "ARN of the IAM role for Cognito service integration (SMS, SNS). Pass this to aws_cognito_user_pool.sms_configuration.sns_caller_arn."
  value       = aws_iam_role.cognito_service_role.arn
}

# ============================================================================
# OUTPUT: cognito_service_role_name
# ----------------------------------------------------------------------------
# What: Human-readable name of the Cognito service role.
# Why: Useful for IAM policy management and debugging.
# Used by: IAM policies, AWS CLI commands.
output "cognito_service_role_name" {
  description = "Name of the Cognito service role. Useful for IAM policy references and AWS CLI operations."
  value       = aws_iam_role.cognito_service_role.name
}