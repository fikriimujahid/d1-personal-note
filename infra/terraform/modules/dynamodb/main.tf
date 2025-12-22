# ============================================================================
# DynamoDB Tables
# ============================================================================
resource "aws_dynamodb_table" "main" {
  for_each = var.tables

  name           = "${var.project}-${var.environment}-${each.key}"
  billing_mode   = each.value.billing_mode # PROVISIONED or PAY_PER_REQUEST
  hash_key       = each.value.hash_key
  range_key      = each.value.range_key
  table_class    = each.value.table_class # STANDARD or STANDARD_INFREQUENT_ACCESS (cost optimization)

  # Attribute definitions
  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Server-side encryption (security best practice - uses AWS owned key)
  server_side_encryption {
    enabled = true
    # kms_key_id omitted = uses AWS owned key (default)
  }

  # Time to Live (TTL) - cost optimization
  dynamic "ttl" {
    for_each = each.value.ttl_attribute != null ? [1] : []
    content {
      enabled        = true
      attribute_name = each.value.ttl_attribute
    }
  }

  # Deletion protection (safety)
  deletion_protection_enabled = each.value.deletion_protection_enabled

  # On-demand throughput (for PAY_PER_REQUEST)
  dynamic "on_demand_throughput" {
    for_each = each.value.on_demand_throughput != null ? [each.value.on_demand_throughput] : []
    content {
      max_read_request_units  = on_demand_throughput.value.max_read_request_units
      max_write_request_units = on_demand_throughput.value.max_write_request_units
    }
  }

  # Tags
  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-${each.key}"
    Table       = each.key
  })
}
