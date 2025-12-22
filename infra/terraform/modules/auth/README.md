# Auth Module (Cognito User Pool)

This module stands up an AWS Cognito User Pool and a web app client for API-driven auth (no Hosted UI). It favors clarity and safe defaults for beginners.

## What it creates
- Cognito User Pool with strong password policy, optional MFA, optional advanced security (PLUS tier).
- User attributes: required `email`, optional `name`, optional custom boolean `custom:email_notification`.
- Device tracking, deletion protection, and user-enumeration protection enabled.
- Web/SPA client with SRP auth + refresh tokens; no client secret.

## Design choices
- No Hosted UI: you call Cognito directly via SRP (`ALLOW_USER_SRP_AUTH`) and refresh tokens.
- OAuth callbacks removed: this client avoids redirect flows. If you later need OAuth, re-enable `allowed_oauth_flows` and callback/logout URLs.
- Client secrets disabled: safe for SPAs; do not add secrets to browser apps.

## Inputs (key variables)
- `project` (string, required): Project name used in resource naming.
- `environment` (string, required): Environment suffix (dev/stage/prod).
- `tags` (map(string), default `{}`): Extra tags merged with Name.
- `cognito_tier` (string, default `LITE`): `LITE` or `PLUS` (required for advanced security).
- `password_min_length` (number, default `12`): Password length floor.
- `enable_mfa` (bool, default `false`): Turn on software-token MFA.
- `enable_advanced_security` (bool, default `false`): Fraud detection (needs PLUS tier).
- `callback_urls`, `logout_urls`: Currently unused because Hosted UI/OAuth is disabled. Remove or re-enable OAuth flows if you need redirects.

## Outputs
- `user_pool_id`: ID of the user pool (e.g., `us-east-1_AbCdEfGhIj`).
- `user_pool_client_id`: ID of the web client (public identifier for your app).
- `user_pool_arn`: ARN of the user pool (use in IAM policies).

## Example usage (API-only auth)
```hcl
module "auth" {
  source = "./infra/terraform/modules/auth"

  project                  = "myapp"
  environment              = "dev"
  cognito_tier             = "LITE"          # use PLUS for advanced security
  password_min_length      = 12
  enable_mfa               = true             # optional
  enable_advanced_security = false            # set true only with PLUS
  tags = {
    Team = "platform"
  }
}
```

## Using the attributes in your app
- Read/write via AWS SDK: `GetUser` / `UpdateUserAttributes`.
- Attribute keys in code: `email`, `name`, and `custom:email_notification`.
- Because the client has read/write permissions for these attributes, the frontend can update them directly.