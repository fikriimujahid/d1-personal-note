# ==============================================================================
# DynamoDB Module Outputs
# ==============================================================================
# PURPOSE:
#   Outputs are Terraform's way of exposing data from this module so other
#   parts of your infrastructure can use it.
#
# WHAT ARE OUTPUTS?
#   Think of outputs as "return values" from a module. When you create resources,
#   AWS generates information about them (like names, IDs, ARNs). Outputs let
#   you pass that information to other modules or display it to users.
#
# WHY ARE OUTPUTS IMPORTANT?
#   1. Resource References: Other modules need table names/ARNs to grant permissions
#   2. Information Display: Show users what was created after 'terraform apply'
#   3. Dependencies: Terraform uses outputs to understand resource dependencies
#   4. Automation: Scripts can use outputs to configure applications
#
# REAL-WORLD EXAMPLE:
#   Your Lambda function needs to know which DynamoDB table to write to.
#   The Lambda module uses this module's 'table_name' output to get the name.
# ==============================================================================

# ------------------------------------------------------------------------------
# OUTPUT: DynamoDB Table Names
# ------------------------------------------------------------------------------
# WHAT THIS OUTPUTS:
#   A map (dictionary) of all table names created by this module.
#
# OUTPUT FORMAT:
#   {
#     "users"   = "myapp-prod-users"
#     "orders"  = "myapp-prod-orders"
#     "logs"    = "myapp-prod-logs"
#   }
#
# HOW TO USE THIS OUTPUT:
#   In another module or root configuration:
#   
#   module "dynamodb" {
#     source = "./modules/dynamodb"
#     tables = var.tables
#   }
#   
#   # Access a specific table name:
#   table_name = module.dynamodb.table_name["users"]
#   # Result: "myapp-prod-users"
#
# WHEN YOU NEED THIS:
#   - Configuring application environment variables
#   - Setting up IAM policies that reference specific tables
#   - Passing table names to Lambda functions
#   - Creating CloudWatch alarms for specific tables
#
# TERRAFORM CONCEPT - for expression:
#   { for k, t in aws_dynamodb_table.main : k => t.name }
#   
#   This is a "for expression" that transforms data:
#   - Loops through all tables in aws_dynamodb_table.main
#   - k = the key (logical table name like "users")
#   - t = the table resource object
#   - k => t.name = creates a map entry: key -> table's actual name
#
#   It's like Python: {k: t.name for k, t in tables.items()}
# ------------------------------------------------------------------------------
output "table_name" {
  description = "Map of DynamoDB table names created by this module (keyed by table logical name)"
  value       = { for k, t in aws_dynamodb_table.main : k => t.name }
}

# ------------------------------------------------------------------------------
# OUTPUT: DynamoDB Table ARNs
# ------------------------------------------------------------------------------
# WHAT THIS OUTPUTS:
#   A map of all table ARNs (Amazon Resource Names) created by this module.
#
# WHAT IS AN ARN?
#   ARN = Amazon Resource Name
#   It's a globally unique identifier for any AWS resource.
#   
#   Format: arn:aws:dynamodb:region:account-id:table/table-name
#   Example: arn:aws:dynamodb:us-east-1:123456789012:table/myapp-prod-users
#
# WHY ARE ARNs IMPORTANT?
#   ARNs are used for:
#   - IAM policies (granting permissions to specific resources)
#   - CloudWatch monitoring (tracking metrics for specific tables)
#   - CloudTrail logging (auditing access to specific resources)
#   - Cross-account access (sharing resources between AWS accounts)
#
# OUTPUT FORMAT:
#   {
#     "users"  = "arn:aws:dynamodb:us-east-1:123456789012:table/myapp-prod-users"
#     "orders" = "arn:aws:dynamodb:us-east-1:123456789012:table/myapp-prod-orders"
#   }
#
# HOW TO USE THIS OUTPUT:
#   Most commonly used in IAM policies:
#   
#   resource "aws_iam_policy" "lambda_dynamodb" {
#     policy = jsonencode({
#       Statement = [{
#         Effect   = "Allow"
#         Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
#         Resource = [module.dynamodb.table_arn["users"]]  # <- Using the ARN here
#       }]
#     })
#   }
#
# ARN vs NAME - WHEN TO USE WHICH?
#   - Use NAME: For application configuration (env vars, SDK clients)
#   - Use ARN: For AWS-to-AWS permissions and monitoring
#
# EXAMPLE COMPARISON:
#   Application Code (needs NAME):
#     dynamodb.Table('myapp-prod-users')  # Uses simple name
#   
#   IAM Policy (needs ARN):
#     Resource: "arn:aws:dynamodb:...:table/myapp-prod-users"  # Full ARN required
# ------------------------------------------------------------------------------
output "table_arn" {
  description = "Map of DynamoDB table ARNs created by this module (keyed by table logical name)"
  value       = { for k, t in aws_dynamodb_table.main : k => t.arn }
}