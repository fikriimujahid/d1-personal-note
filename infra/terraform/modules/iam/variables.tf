### Input Variables for IAM Module
# Purpose: Define the configurable parameters that make this module reusable across projects.

# TERRAFORM CONCEPT: Variables are the "function parameters" of a module.
# They allow the module to be configured differently when called from different environments.
# Variables can have: type, description, default value, and validation rules.

# ============================================================================
# VARIABLE: project
# ----------------------------------------------------------------------------
# What: The name of your project or application.
# Why: Used to namespace all IAM resources so they don't conflict with other projects.
# Example: "myapp", "notes-api", "ecommerce"
# Usage: Creates resources like "myapp-lambda-execution-dev"
variable "project" {
  description = "Project name used for resource naming and namespacing. Should be lowercase and hyphen-separated."
  type        = string
  
  # TERRAFORM CONCEPT: validation blocks enforce constraints at plan time.
  # This catches configuration errors before attempting to create resources.
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
  
  validation {
    condition     = length(var.project) >= 3 && length(var.project) <= 32
    error_message = "Project name must be between 3 and 32 characters to ensure valid AWS resource names."
  }
}

# ============================================================================
# VARIABLE: environment
# ----------------------------------------------------------------------------
# What: The deployment environment (development, staging, production).
# Why: Isolates resources between environments and allows different configurations.
# Example: "dev", "staging", "main"
# Usage: Creates resources like "myapp-lambda-execution-dev" vs "myapp-lambda-execution-main"
variable "environment" {
  description = "Environment name (dev, staging, main). Used for resource naming and environment-specific configurations."
  type        = string
  
  # TERRAFORM CONCEPT: validation with allowed values creates an "enum" behavior.
  validation {
    condition     = contains(["dev", "staging", "main"], var.environment)
    error_message = "Environment must be one of: dev, staging, main."
  }
}

# ============================================================================
# VARIABLE: tags
# ----------------------------------------------------------------------------
# What: Key-value pairs attached to all AWS resources for organization.
# Why: Essential for cost tracking, automation, and compliance.
# Example: { "Team" = "Backend", "CostCenter" = "Engineering" }
# Usage: Applied to every IAM role created by this module.
variable "tags" {
  description = "Common tags to apply to all IAM resources. Used for cost allocation, ownership tracking, and compliance."
  type        = map(string)
  
  # TERRAFORM CONCEPT: default = {} means tags are optional.
  # If not provided, resources get an empty tag set.
  default     = {}
  
  # Example of how tags might be used:
  # tags = {
  #   "Team"        = "Backend"
  #   "CostCenter"  = "Engineering"
  #   "ManagedBy"   = "Terraform"
  #   "Compliance"  = "SOC2"
  # }
}