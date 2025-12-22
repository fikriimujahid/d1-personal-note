variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tables" {
  description = "Map of DynamoDB tables to create"
  type = map(object({
    # Table configuration
    billing_mode = string # PROVISIONED or PAY_PER_REQUEST
    table_class  = string # STANDARD or STANDARD_INFREQUENT_ACCESS

    # Key schema
    hash_key  = string
    range_key = string 

    # Attributes
    attributes = list(object({
      name = string
      type = string # S, N, B
    }))

    # Security
    deletion_protection_enabled = bool

    # Cost optimization
    ttl_attribute = string # Attribute name for TTL

    # On-demand throughput (optional, for PAY_PER_REQUEST billing mode)
    on_demand_throughput = object({
      max_read_request_units  = number
      max_write_request_units = number
    })
  }))
  default = {}
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}