### AWS Cognito authentication stack (user pool + web client)
# Goal: Beginner-friendly, production-safe defaults with clear Terraform concepts called out inline.

# TERRAFORM CONCEPT: Data sources only READ existing AWS objects; they never create anything.
# Here we read the current AWS region so all names/tags can include it if needed.
data "aws_region" "current" {}

# ============================================================================
# RESOURCE: Cognito User Pool
# ----------------------------------------------------------------------------
# What: The managed identity store where users sign up/sign in.
# Why: Central place for password policy, MFA, and account recovery.
# Security: Strong password rules, optional MFA, and deletion protection enabled.
# Cost: "LITE" is cheaper; "PLUS" enables advanced security (fraud detection).
resource "aws_cognito_user_pool" "main" {
  # Naming convention keeps resources unique per project/environment.
  name = "${var.project}-${var.environment}-user-pool"

  # Choose between LITE and PLUS tiers at apply time.
  user_pool_tier = var.cognito_tier

  # Let users sign in with their email address (friendlier than usernames).
  username_attributes = ["email"]

  # No attributes are auto-verified here; verification is handled in the app flow.
  auto_verified_attributes = ["email"]

  # TERRAFORM CONCEPT: Nested block keeps related settings grouped.
  username_configuration {
    # Case-insensitive login avoids duplicate accounts (User@example == user@example).
    case_sensitive = false
  }

  # Password rules follow NIST guidance: emphasize length and balanced complexity.
  password_policy {
    minimum_length                   = var.password_min_length
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # MFA is optional to keep onboarding simple; flip var.enable_mfa to enforce it.
  mfa_configuration = var.enable_mfa ? "OPTIONAL" : "OFF"

  # TERRAFORM CONCEPT: dynamic blocks let us add configuration only when enabled.
  dynamic "software_token_mfa_configuration" {
    for_each = var.enable_mfa ? [1] : []
    content {
      enabled = true
    }
  }

  # Account recovery prioritizes verified email.
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Attribute schema explicitly documents what we store and whether users can change it.
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 2048
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "email_notification"
    attribute_data_type = "Boolean"
    required            = false
    mutable             = true
  }

  # Conditional advanced security (only available in PLUS tier).
  dynamic "user_pool_add_ons" {
    for_each = var.enable_advanced_security ? [1] : []
    content {
      # ENFORCED blocks risky sign-ins automatically.
      advanced_security_mode = "ENFORCED"
    }
  }

  # Track remembered devices and challenge new ones.
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  # Email delivery uses Cognito's default sender to reduce setup; switch to SES for branded emails.
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
    # To brand emails later: set email_sending_account = "DEVELOPER" and provide an SES source_arn.
  }

  # Prevent accidental deletion of the user pool during destroy.
  deletion_protection = "ACTIVE"

  # Tags help with cost allocation and inventory.
  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-user-pool"
  })
}


# ============================================================================
# RESOURCE: Cognito User Pool Client (Web Application)
# ----------------------------------------------------------------------------
# What: Public client used by the web/SPA to exchange credentials for tokens.
# Why: Separates web access from other potential clients (mobile, backend) with tailored settings.
# Security: No client secret (cannot be kept in a browser); SRP and refresh-token flows only.
resource "aws_cognito_user_pool_client" "web" {
  name = "${var.project}-${var.environment}-web-client"

  # TERRAFORM CONCEPT: attribute references create an implicit dependency on the user pool.
  user_pool_id = aws_cognito_user_pool.main.id

  # Browser clients must not have secrets; SRP keeps passwords off the wire.
  generate_secret = false

  # Allowed authentication flows for the web app.
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    # Optional in dev only: 
    "ALLOW_USER_PASSWORD_AUTH"
  ]

  # Control which attributes the app can read/write (includes custom flag for notifications).
  read_attributes  = ["email", "name", "custom:email_notification"]
  write_attributes = ["email", "name", "custom:email_notification"]

  # Token lifetimes balance security (short access tokens) and UX (longer refresh tokens).
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Hide user existence differences to block enumeration attacks.
  prevent_user_existence_errors = "ENABLED"

  # Allow immediate logout/token invalidation instead of waiting for expiry.
  enable_token_revocation = true

  # No hosted UI; authentication happens via API calls from the SPA.
}

# LEARNING NOTES
# - Data sources (like aws_region) read existing info; resources (user_pool, client) create/manage it.
# - Conditional blocks (dynamic with for_each) keep the config minimal until a feature is enabled.
# - Common beginner pitfalls: enabling USER_PASSWORD_AUTH in production, omitting deletion_protection,
#   or forgetting to shorten access token validity for security.
