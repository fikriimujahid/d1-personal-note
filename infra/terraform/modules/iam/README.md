# IAM Module (Roles & Policies)

This module creates AWS IAM roles and policies for Lambda functions and Cognito services. It implements least-privilege access with clear security boundaries and beginner-friendly documentation.

## What it creates

**Lambda Execution Infrastructure:**
- IAM role that Lambda functions assume during execution
- Inline policy granting permissions to:
  - CloudWatch Logs (debugging and monitoring)
  - DynamoDB (data storage with naming pattern restrictions)
  - Secrets Manager (secure configuration values)

**Cognito Service Infrastructure:**
- IAM role for Cognito service integrations
- Currently empty policy (ready for SMS MFA or other features)

All resources follow the naming pattern: `{project}-{resource-type}-{environment}`

## Design choices

**Inline vs Managed Policies:**  
Uses inline policies for clarity and single-purpose use. Each role has exactly one policy attached, making permissions easy to audit and understand.

**Resource Scoping:**  
Permissions are restricted to resources matching the project naming pattern:
- DynamoDB: `{project}-*-{environment}` tables only
- Secrets Manager: `{project}/*` secrets only
- CloudWatch Logs: Currently uses wildcards (common pattern for Lambda logs)

**Security-First:**  
- Minimal permissions following AWS least-privilege principles
- Trust policies limit role assumption to specific AWS services
- Resource ARNs use patterns to prevent cross-project access
- All security trade-offs documented inline

## Inputs (key variables)

- `project` (string, **required**): Project name for resource namespacing.  
  *Validation: 3-32 characters, lowercase letters, numbers, hyphens only*
  
- `environment` (string, **required**): Deployment environment.  
  *Validation: Must be one of: dev, staging, main*
  
- `tags` (map(string), default `{}`): Additional tags for cost allocation and organization.

## Outputs

**Lambda Execution Role:**
- `lambda_execution_role_arn`: ARN for Lambda function configuration (`aws_lambda_function.role`)
- `lambda_execution_role_name`: Human-readable name for IAM policies and CLI operations

**Cognito Service Role:**
- `cognito_service_role_arn`: ARN for Cognito SMS/SNS configuration (`aws_cognito_user_pool.sms_configuration`)
- `cognito_service_role_name`: Human-readable name for IAM policies and CLI operations

## Example usage

```hcl
module "iam" {
  source = "./infra/terraform/modules/iam"

  project     = "myapp"
  environment = "dev"
  
  tags = {
    Team       = "Backend"
    CostCenter = "Engineering"
    ManagedBy  = "Terraform"
  }
}

# Use the Lambda role in a Lambda function
resource "aws_lambda_function" "api" {
  function_name = "${var.project}-api-${var.environment}"
  role          = module.iam.lambda_execution_role_arn  # ← Uses the output
  
  # ... other Lambda configuration
}

# Use the Cognito role in a User Pool (when enabling SMS MFA)
resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-${var.environment}-users"
  
  sms_configuration {
    sns_caller_arn = module.iam.cognito_service_role_arn  # ← Uses the output
    external_id    = "cognito-sms"
  }
}
```

## Security considerations

**Current Permissions:**
- ✅ Lambda can read/write project-specific DynamoDB tables
- ✅ Lambda can read project-specific secrets
- ✅ Lambda can write logs to CloudWatch
- ⚠️ CloudWatch Logs uses wildcards (standard for Lambda, but could be more specific)

**What Lambda CANNOT do:**
- ❌ Access S3 buckets (no S3 permissions)
- ❌ Access other projects' DynamoDB tables (pattern restricted)
- ❌ Access other projects' secrets (namespace restricted)
- ❌ Modify IAM roles or policies (no IAM permissions)

**Improving Security:**
You can make CloudWatch Logs more restrictive by replacing the wildcard in `main.tf`:
```hcl
# Current (broad):
Resource = "arn:aws:logs:*:*:*"

# Better (specific):
Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-*"
```

## Permissions granted to Lambda

| Service | Actions | Resource Scope | Why Needed |
|---------|---------|----------------|------------|
| **CloudWatch Logs** | CreateLogGroup<br>CreateLogStream<br>PutLogEvents | All log groups | Lambda automatically creates log groups; wildcards are standard |
| **DynamoDB** | GetItem, PutItem<br>Query, UpdateItem<br>DeleteItem | Tables matching<br>`{project}-*-{environment}` | Backend data storage (notes, user data, etc.) |
| **Secrets Manager** | GetSecretValue | Secrets in<br>`{project}/*` namespace | API keys, DB credentials, third-party tokens |

## Common beginner questions

**Q: Why separate role and policy resources?**  
A: Roles define *identity* (who can assume), policies define *permissions* (what they can do). Separating them follows AWS best practices and makes updates easier.

**Q: When would I modify this module?**  
A: When Lambda needs new AWS service permissions. For example:
- Add S3 permissions for file uploads
- Add SES permissions for sending emails
- Add SNS permissions for sending notifications

**Q: Should I use managed policies instead?**  
A: Managed policies (like `AWSLambdaBasicExecutionRole`) are convenient but less specific. Inline policies give you precise control and document exactly what your Lambda can access.

**Q: What's the difference between trust policy and permission policy?**  
A: 
- **Trust policy** (`assume_role_policy`): WHO can wear this role (Lambda service)
- **Permission policy** (`policy`): WHAT the role can do (access DynamoDB, read secrets)

**Q: Is the Cognito role needed if I'm not using SMS MFA?**  
A: No, but it's included for future features. If you never use SMS/SNS features, this role remains unused but doesn't cost anything.

## Learning resources

- [AWS IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)
- [Lambda Execution Role](https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html)
- [IAM Policy Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Least Privilege Principle](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege)
