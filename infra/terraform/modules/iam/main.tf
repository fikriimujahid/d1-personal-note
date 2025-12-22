### AWS IAM roles and policies for Lambda and Cognito services
# Goal: Secure, minimal-privilege access for backend Lambda functions and Cognito user management.

# TERRAFORM CONCEPT: Data sources only READ existing AWS objects; they never create anything.
# Here we read the current AWS region and account ID for constructing precise resource ARNs.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================================================
# RESOURCE: Lambda Execution Role
# ----------------------------------------------------------------------------
# What: IAM role that Lambda functions assume when they execute.
# Why: Lambda needs permission to access other AWS services (logs, DynamoDB, Secrets Manager).
# Security: This role grants identity; the attached policy grants permissions.
# Used by: All backend Lambda functions in this project.
resource "aws_iam_role" "lambda_execution_role" {
  # Naming convention keeps resources unique per project/environment.
  name = "${var.project}-lambda-execution-${var.environment}"

  # TERRAFORM CONCEPT: assume_role_policy defines WHO can use this role (trust policy).
  # Here we trust the Lambda service to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Action: What the trusted entity can do (assume this role).
        Action = "sts:AssumeRole"
        # Effect: ALLOW means permission is granted.
        Effect = "Allow"
        # Principal: WHO is trusted (the Lambda service).
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  # Tags help with cost allocation and inventory.
  tags = merge(var.tags, {
    Name = "${var.project}-lambda-execution-${var.environment}"
  })
}

# ============================================================================
# RESOURCE: Lambda Execution Policy (Inline)
# ----------------------------------------------------------------------------
# What: Policy attached directly to the Lambda role that grants specific AWS permissions.
# Why: Lambda needs to write logs, access DynamoDB tables, and read secrets.
# Security: Scoped to specific resources using naming patterns (least privilege).
# Alternative: Could use managed policies, but inline gives us precise control.
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${var.project}-lambda-execution-policy-${var.environment}"
  
  # TERRAFORM CONCEPT: attribute references create an implicit dependency.
  # This policy won't be created until the role exists.
  role = aws_iam_role.lambda_execution_role.id

  # TERRAFORM CONCEPT: policy defines WHAT actions are allowed on WHICH resources.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # PERMISSION 1: CloudWatch Logs (for debugging and monitoring)
      # ------------------------------------------------------------------
      # Why: Every Lambda needs to write execution logs.
      # Security risk: Uses wildcards (*) in Resource. This is acceptable for logs
      # because log groups are created dynamically by Lambda.
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",   # Create log group on first invocation
          "logs:CreateLogStream",  # Create log stream for each execution
          "logs:PutLogEvents"      # Write log entries
        ]
        # Resource scope: All log groups in this region/account.
        # Better alternative: "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-*"
        Resource = "arn:aws:logs:*:*:*"
      },
      
      # PERMISSION 2: DynamoDB (for data storage)
      # ------------------------------------------------------------------
      # Why: Lambda functions read/write application data to DynamoDB tables.
      # Security: Limited to tables matching our naming pattern (project-*-environment).
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",     # Read single item by key
          "dynamodb:PutItem",     # Write/overwrite single item
          "dynamodb:Query",       # Read multiple items efficiently
          "dynamodb:UpdateItem",  # Modify specific attributes
          "dynamodb:DeleteItem"   # Remove item
        ]
        # Resource scope: Only tables following our naming convention.
        # Pattern: ${project}-*-${environment} (e.g., myapp-notes-dev)
        Resource = "arn:aws:dynamodb:*:*:table/${var.project}-*-${var.environment}"
      },
      
      # PERMISSION 3: Secrets Manager (for sensitive configuration)
      # ------------------------------------------------------------------
      # Why: Lambda needs API keys, database credentials, etc. without hardcoding.
      # Security: Read-only access; limited to secrets under project namespace.
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"  # Read secret value only
        ]
        # Resource scope: Only secrets in our project folder.
        # Pattern: ${project}/* (e.g., myapp/db-password)
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project}/*"
      }
    ]
  })
}

# ============================================================================
# RESOURCE: Cognito Service Role
# ----------------------------------------------------------------------------
# What: IAM role for Cognito to perform administrative actions (SMS, email, etc.).
# Why: Cognito may need to send SMS messages or integrate with other AWS services.
# Security: This role is currently unused but created for future Cognito features.
# Note: If you're not using Cognito features that need IAM (like SMS_MFA with SNS),
#       this role doesn't need any attached policies yet.
resource "aws_iam_role" "cognito_service_role" {
  # Naming convention keeps resources unique per project/environment.
  name = "${var.project}-cognito-service-${var.environment}"

  # TERRAFORM CONCEPT: assume_role_policy defines WHO can use this role (trust policy).
  # Here we trust the Cognito Identity Provider service to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Action: What the trusted entity can do (assume this role).
        Action = "sts:AssumeRole"
        # Effect: ALLOW means permission is granted.
        Effect = "Allow"
        # Principal: WHO is trusted (the Cognito IDP service).
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
      }
    ]
  })

  # Tags help with cost allocation and inventory.
  tags = merge(var.tags, {
    Name = "${var.project}-cognito-service-${var.environment}"
  })
}