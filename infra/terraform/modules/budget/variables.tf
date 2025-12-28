variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "limit_amount" {
  description = "The amount of cost limit"
  type        = string
  default     = "10"
}

variable "limit_unit" {
  description = "The unit of cost limit"
  type        = string
  default     = "USD"
}

variable "notification_emails" {
  description = "List of email addresses to notify when budget is exceeded"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
