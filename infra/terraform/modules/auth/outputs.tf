# ============================================================================
# Authentication Module - Output Values
# ============================================================================
# TERRAFORM CONCEPT: Outputs
# Outputs are the "return values" of a module - they pass data to the outside world
#
# WHY USE OUTPUTS?
# 1. Return IDs so other modules can reference this module's resources
# 2. Display important values after deployment (without parsing code)
# 3. Pass data between modules (module A's outputs → module B's inputs)
#
# ANALOGY: If resources are the cake, outputs are slicing it and serving portions
# You don't need everything, just the key IDs and identifiers
#
# TYPICAL WORKFLOW:
# 1. Create a user pool with this module
# 2. Get back user_pool_id via output
# 3. Pass user_pool_id to other modules that need to integrate
# 4. Other modules can create clients, groups, etc. attached to this pool

output "user_pool_id" {
  description = "The unique ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id

  # WHY THIS OUTPUT?
  # The user pool ID is required for almost everything Cognito-related:
  # - Creating additional clients
  # - Adding users programmatically
  # - Integrating with APIs
  # - Attaching resource policies
  #
  # EXAMPLE:
  # If other_module needs to access the user pool, it uses:
  #   var.user_pool_id = module.auth.user_pool_id
  #
  # WHAT IS IT?
  # An alphanumeric string like: us-east-1_AbCdEfGhIj
  # Format: {region}_{random_string}
  # Unique within AWS account, used as identifier
}

output "user_pool_client_id" {
  description = "The unique ID of the Cognito User Pool Client for web applications"
  value       = aws_cognito_user_pool_client.web.id

  # WHY THIS OUTPUT?
  # The client ID is what your web app needs to authenticate users
  # Your frontend JavaScript uses this to call Cognito APIs
  #
  # EXAMPLE FRONTEND CODE:
  # const cognitoClient = new AmazonCognitoIdentity.CognitoUserPool({
  #   UserPoolId: userPoolId,          // from output
  #   ClientId: userPoolClientId       // from this output
  # });
  #
  # WHAT IS IT?
  # A 26-character alphanumeric string like: 1a2b3c4d5e6f7g8h9i0j1k2l3m
  # Public identifier (safe to include in frontend code)
  # Note: Without a client secret (which we don't have), this is safe
  #
  # SECURITY NOTE:
  # This ClientId is NOT sensitive - it's meant to be public
  # Never expose CLIENT_SECRET (if you had one) in frontend code
}

output "user_pool_arn" {
  description = "The ARN (Amazon Resource Name) of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn

  # WHY THIS OUTPUT?
  # ARNs are used for:
  # - IAM permissions (giving services access to this user pool)
  # - Resource policies (controlling who can access the pool)
  # - Cross-service integration
  #
  # EXAMPLE IAM POLICY:
  # {
  #   "Effect": "Allow",
  #   "Action": "cognito-idp:*",
  #   "Resource": "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_AbCdEfGhIj"
  # }
  # This policy grants permissions only to THIS specific user pool
  #
  # WHAT IS IT?
  # ARN = Amazon Resource Name, a unique identifier for AWS resources
  # Format: arn:aws:service:region:account-id:resource-type/resource-id
  # Example: arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_AbCdEfGhIj
  #
  # WHY NOT JUST USE ID?
  # ARN is used in AWS policies and cross-account scenarios
  # ID is used within Cognito itself
  # Both are useful for different purposes
}