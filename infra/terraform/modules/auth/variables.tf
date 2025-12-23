# ============================================================================
# Authentication Module - Input Variables
# ============================================================================
# TERRAFORM CONCEPT: Variables
# Variables are like function parameters - they let you customize module behavior
# without changing the code itself. Define once, reuse across environments.
#
# There are two types of variables in Terraform:
# 1. INPUT VARIABLES (in this file): Settings you provide when using the module
# 2. LOCAL VALUES: Computed values used internally (usually in main.tf)
#
# NAMING PATTERN: Keep variable names short but descriptive
# Prefix with the service: cognito_tier, enable_mfa, password_min_length

# ============================================================================
# REQUIRED VARIABLES: No defaults - you MUST provide these
# ============================================================================

variable "project" {
  description = "Project name (e.g., 'myapp', 'acme')"
  type        = string

  # WHY THIS MATTERS:
  # This is used in resource names to identify which project owns this infrastructure
  # EXAMPLE: "myapp-production-user-pool"
  # Helps when you have multiple projects in the same AWS account
}

variable "environment" {
  description = "Environment name (e.g., 'development', 'staging', 'production')"
  type        = string

  # WHY THIS MATTERS:
  # Keeps infrastructure separated by environment
  # EXAMPLE: You want different password rules for dev vs production
  # Dev: weak passwords for easy testing
  # Production: strong passwords for security
}

# ============================================================================
# OPTIONAL VARIABLES: Have defaults - you can override them
# ============================================================================

variable "tags" {
  description = "Resource tags for billing and organization"
  type        = map(string)

  # TERRAFORM CONCEPT: map(string)
  # A map is a collection of key-value pairs (like a dictionary in Python)
  # Example:
  #   tags = {
  #     "Team"       = "Platform"
  #     "CostCenter" = "Engineering"
  #     "Project"    = "Auth"
  #   }
  #
  # WHY USE TAGS?
  # - Cost allocation: See how much each team/project spends
  # - Resource discovery: Filter by team or purpose
  # - Automation: Run scripts only on tagged resources
  #
  # WHY DEFAULT TO EMPTY?
  # Some users might not need tags, so empty {} is a reasonable default
  default = {}
}

variable "cognito_tier" {
  description = "Cognito User Pool tier: 'LITE' (cheaper) or 'PLUS' (advanced security features)"
  type        = string
  default     = "LITE"

  # COST vs SECURITY TRADE-OFF:
  # LITE ($0.0015 per MAU - Monthly Active User):
  # - Basic authentication
  # - No advanced security (fraud detection)
  # - Best for development, low-risk applications
  #
  # PLUS ($0.025 per MAU, 17x more expensive):
  # - Advanced security features (fraud detection, suspicious login blocking)
  # - Adaptive authentication (risk-based decisions)
  # - Best for production, financial apps, sensitive data
  #
  # RECOMMENDATION:
  # - Development: LITE (save money during development)
  # - Production: PLUS if handling sensitive data, LITE if not
  #
  # HOW TO OVERRIDE:
  #   module "auth" {
  #     cognito_tier = "PLUS"  # Use advanced security in production
  #   }
}

variable "password_min_length" {
  description = "Minimum password length (AWS minimum: 6, recommended: 12+)"
  type        = number
  default     = 12

  # SECURITY PRINCIPLE: Length matters more than complexity
  # NIST (National Institute of Standards & Technology) recommends:
  # - Long passwords beat complex passwords
  #
  # EXAMPLES:
  # Weak:   "P@ssw0rd" (8 chars, complex) → takes ~8 hours to crack
  # Better: "correct horse battery staple" (28 chars, simple) → takes ~1000 years to crack
  #
  # WHY 12?
  # - 8 characters: Industry minimum, but getting weak
  # - 12 characters: Sweet spot - secure but still memorable
  # - 16+: Very secure, but annoying for users
  #
  # PASSWORD CRACKING MATH:
  # Each additional character multiplies cracking time by 26-36x (alphabet size)
  # So 12 chars is dramatically more secure than 8
}

variable "enable_mfa" {
  description = "Enable Multi-Factor Authentication (requires authentication app like Google Authenticator)"
  type        = bool
  default     = false

  # MFA (Multi-Factor Authentication):
  # Requires TWO things to log in:
  # 1. Password (something you know)
  # 2. Authenticator app code (something you have)
  #
  # SECURITY BENEFIT:
  # Even if attacker has your password, they can't log in without your phone
  # Dramatically reduces account takeovers
  #
  # TYPES OF MFA:
  # - SMS: Text message code (vulnerable to SIM swapping attacks)
  # - Software Token: Authenticator app (Google Auth, Authy, Microsoft Auth)
  # - Hardware Token: Physical USB key (most secure, least convenient)
  #
  # This module uses SOFTWARE TOKEN (authenticator app) - best balance
  #
  # DEFAULT: false
  # WHY? Not all applications need MFA. Trade-off with user convenience.
  # - Healthcare/Finance: Enable MFA
  # - Public blog: Disable MFA
  #
  # HOW TO ENABLE:
  #   module "auth" {
  #     enable_mfa = true
  #   }
}

variable "enable_advanced_security" {
  description = "Enable Advanced Security Features (fraud detection, suspicious login blocking) - requires PLUS tier"
  type        = bool
  default     = false

  # ADVANCED SECURITY FEATURES:
  # AWS Cognito can analyze login patterns and detect suspicious activity
  #
  # EXAMPLES OF SUSPICIOUS ACTIVITY:
  # - User logs in from China, then 10 minutes later from California (impossible)
  # - New IP address, unusual browser/device
  # - Unusual time of day (night owl suddenly logging in at 3 AM)
  #
  # RESPONSE OPTIONS:
  # - AUDIT: Log the suspicious activity but allow login (monitoring)
  # - ENFORCED: Block the suspicious login, require additional verification
  #
  # IMPORTANT: Only works with PLUS tier (not LITE)
  # If you set this to true but use LITE tier, it will be ignored
  #
  # DEFAULT: false
  # WHY? Adds cost and complexity. Only needed for high-security apps.
  #
  # WHO SHOULD ENABLE?
  # - Banks, insurance, healthcare: YES
  # - Startups, public apps: Maybe later, not now
}