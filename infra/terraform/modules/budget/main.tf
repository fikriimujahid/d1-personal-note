# ==============================================================================
# AWS Budget - Project-Specific Cost Tracking
# ==============================================================================
# This budget tracks costs ONLY for resources tagged with this project.
# Without the cost_filter, it would track ALL costs in the AWS account.
#
# How it works:
# - Filters by the "project" tag (e.g., project=d1-personal-note)
# - Only counts resources created/managed by this Terraform project
# - Excludes costs from other projects or untagged resources
#
# Important: All resources must be properly tagged for accurate tracking!
# ==============================================================================

resource "aws_budgets_budget" "cost" {
  name              = "${var.project}-${var.environment}-budget"
  budget_type       = "COST"
  limit_amount      = var.limit_amount
  limit_unit        = var.limit_unit
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"

  # Filter costs to only include resources tagged with this project
  # Format: "user:TagKey$TagValue" for user-defined tags
  cost_filter {
    name   = "TagKeyValue"
    values = ["user:project$${var.project}"]
  }

  # Notification 1: Alert at 80% of budget (actual spending)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_emails
  }

  # Notification 2: Alert at 100% of budget (forecasted)
  # AWS predicts you'll exceed budget based on current spending trends
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.notification_emails
  }

  tags = var.tags
}
