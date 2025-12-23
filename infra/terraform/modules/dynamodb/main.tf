# ============================================================================
# DynamoDB Tables Module
# ============================================================================
# PURPOSE:
#   This module creates DynamoDB tables for the application.
#   DynamoDB is AWS's fully managed NoSQL database service.
#
# WHAT IS DYNAMODB?
#   - A NoSQL database (stores data as key-value pairs or documents)
#   - Fully managed by AWS (no servers to maintain)
#   - Scales automatically based on demand
#   - Designed for high-performance applications
#
# WHY USE A MODULE?
#   This code is reusable. You can create multiple DynamoDB tables with
#   different configurations by passing different variables to this module.
# ============================================================================

# ----------------------------------------------------------------------------
# RESOURCE: DynamoDB Table
# ----------------------------------------------------------------------------
# WHAT THIS DOES:
#   Creates one or more DynamoDB tables based on the 'var.tables' input.
#
# HOW IT WORKS:
#   The 'for_each' loop creates a separate table for each entry in var.tables.
#   If var.tables has 3 entries, this creates 3 separate DynamoDB tables.
#
# TERRAFORM CONCEPT - for_each:
#   for_each allows you to create multiple similar resources from a map.
#   Each iteration uses 'each.key' (table name) and 'each.value' (settings).
# ----------------------------------------------------------------------------
resource "aws_dynamodb_table" "main" {
  # Loop through each table configuration provided in var.tables
  for_each = var.tables

  # --------------------------------------------------------------------------
  # Table Naming Convention
  # --------------------------------------------------------------------------
  # FORMAT: {project}-{environment}-{table-name}
  # EXAMPLE: myapp-prod-users
  #
  # WHY THIS NAMING?
  #   - Prevents naming conflicts across projects
  #   - Makes it easy to identify which environment a table belongs to
  #   - Follows AWS best practices for resource naming
  # --------------------------------------------------------------------------
  name = "${var.project}-${var.environment}-${each.key}"

  # --------------------------------------------------------------------------
  # Billing Mode
  # --------------------------------------------------------------------------
  # WHAT THIS IS:
  #   How AWS charges you for using this table.
  #
  # OPTIONS:
  #   - PAY_PER_REQUEST (On-Demand):
  #       * Pay only for the reads/writes you actually use
  #       * Great for unpredictable workloads
  #       * No capacity planning needed
  #
  #   - PROVISIONED:
  #       * Pre-specify read/write capacity
  #       * Lower cost if traffic is predictable
  #       * Requires capacity planning
  #
  # BEGINNER TIP:
  #   Start with PAY_PER_REQUEST (on-demand) unless you have predictable,
  #   steady traffic patterns.
  # --------------------------------------------------------------------------
  billing_mode = each.value.billing_mode

  # --------------------------------------------------------------------------
  # Primary Key Configuration
  # --------------------------------------------------------------------------
  # WHAT IS A PRIMARY KEY?
  #   Every item (row) in DynamoDB must have a unique identifier.
  #   This is how DynamoDB finds and retrieves your data.
  #
  # HASH KEY (Partition Key):
  #   - Required for all tables
  #   - Used to distribute data across multiple servers
  #   - Example: user_id, order_id
  #
  # RANGE KEY (Sort Key):
  #   - Optional
  #   - Used to sort items with the same hash key
  #   - Enables range queries
  #   - Example: timestamp, version_number
  #
  # REAL-WORLD EXAMPLE:
  #   For a table storing user orders:
  #   - hash_key = "user_id" (groups all orders by user)
  #   - range_key = "order_date" (sorts orders by date)
  #   This lets you query "all orders for user123 in December 2025"
  # --------------------------------------------------------------------------
  hash_key  = each.value.hash_key
  range_key = each.value.range_key

  # --------------------------------------------------------------------------
  # Table Class (Storage Optimization)
  # --------------------------------------------------------------------------
  # WHAT THIS IS:
  #   Determines which storage tier to use for cost optimization.
  #
  # OPTIONS:
  #   - STANDARD:
  #       * Default option
  #       * Best for frequently accessed data
  #
  #   - STANDARD_INFREQUENT_ACCESS (IA):
  #       * 50% cheaper storage costs
  #       * Slightly higher read/write costs
  #       * Best for data accessed less than once per month
  #
  # WHEN TO USE INFREQUENT ACCESS?
  #   - Archive data
  #   - Historical records
  #   - Backup tables
  # --------------------------------------------------------------------------
  table_class = each.value.table_class

  # --------------------------------------------------------------------------
  # Attribute Definitions
  # --------------------------------------------------------------------------
  # WHAT ARE ATTRIBUTES?
  #   Attributes are like columns in a traditional database.
  #   In DynamoDB, you only define attributes that are used in keys or indexes.
  #
  # WHY "DYNAMIC" BLOCK?
  #   The 'dynamic' keyword lets us create 0 or more attribute blocks based
  #   on the list in each.value.attributes. This makes the code flexible.
  #
  # ATTRIBUTE TYPES:
  #   - S = String (text)
  #   - N = Number (integers or decimals)
  #   - B = Binary (images, files)
  #
  # BEGINNER MISTAKE:
  #   You do NOT need to define every attribute here, only the ones used
  #   in primary keys or secondary indexes. DynamoDB is schema-less!
  # --------------------------------------------------------------------------
  dynamic "attribute" {
    # Loop through each attribute definition
    for_each = each.value.attributes

    content {
      name = attribute.value.name # Attribute name (e.g., "user_id")
      type = attribute.value.type # Data type: S, N, or B
    }
  }

  # --------------------------------------------------------------------------
  # Server-Side Encryption (SECURITY)
  # --------------------------------------------------------------------------
  # WHAT THIS DOES:
  #   Automatically encrypts all data stored in the table.
  #   Data is encrypted at rest (when stored on disk).
  #
  # SECURITY BENEFIT:
  #   If someone gains physical access to AWS servers, they cannot read
  #   your data without the encryption key.
  #
  # ENCRYPTION KEY OPTIONS:
  #   1. AWS Owned Key (used here - FREE):
  #      - Managed entirely by AWS
  #      - No additional cost
  #      - No key management required
  #      - Cannot view or audit key usage
  #
  #   2. AWS Managed Key (optional - costs ~$1/month):
  #      - Managed by AWS but dedicated to your account
  #      - Can view usage in CloudTrail logs
  #      - Better for compliance requirements
  #
  #   3. Customer Managed Key (optional - costs ~$1/month + usage):
  #      - You control the key completely
  #      - Can rotate, disable, or delete the key
  #      - Required for strict compliance (HIPAA, PCI-DSS)
  #
  # BEST PRACTICE:
  #   Always enable encryption. AWS owned key is fine for most use cases.
  # --------------------------------------------------------------------------
  server_side_encryption {
    enabled = true
    # kms_key_id omitted = uses AWS owned key (default, free option)
    # To use a customer-managed key, add: kms_key_id = aws_kms_key.example.arn
  }

  # --------------------------------------------------------------------------
  # Time to Live (TTL) - Automatic Data Expiration
  # --------------------------------------------------------------------------
  # WHAT THIS DOES:
  #   Automatically deletes items after a specified time.
  #
  # HOW IT WORKS:
  #   - Add a number attribute to each item (Unix timestamp)
  #   - DynamoDB checks this attribute periodically
  #   - Items with timestamps in the past are automatically deleted
  #   - Deletion happens within 48 hours (not instant)
  #
  # COST BENEFIT:
  #   TTL deletions are FREE! You don't pay for these delete operations.
  #
  # USE CASES:
  #   - Session data (expire after 1 hour)
  #   - Temporary data (expire after 30 days)
  #   - Log data (expire after 90 days)
  #
  # EXAMPLE:
  #   If ttl_attribute = "expires_at" and an item has:
  #   { "id": "123", "expires_at": 1700000000 }
  #   The item will be deleted after that timestamp passes.
  #
  # WHY THE COMPLEX FOR_EACH?
  #   This creates the TTL block only if ttl_attribute is provided.
  #   If null, no TTL block is created (TTL is disabled).
  # --------------------------------------------------------------------------
  dynamic "ttl" {
    # Create TTL block only if ttl_attribute is not null
    # The [1] creates a list with one element to iterate over
    for_each = each.value.ttl_attribute != null ? [1] : []

    content {
      enabled        = true
      attribute_name = each.value.ttl_attribute # Name of the timestamp attribute
    }
  }

  # --------------------------------------------------------------------------
  # Deletion Protection (SAFETY)
  # --------------------------------------------------------------------------
  # WHAT THIS DOES:
  #   Prevents accidental deletion of the table.
  #
  # HOW IT WORKS:
  #   If enabled, you must first disable deletion protection before you can
  #   delete the table. This requires two separate actions.
  #
  # WHEN TO ENABLE:
  #   - Production databases with critical data
  #   - Tables that should never be deleted
  #
  # WHEN TO DISABLE:
  #   - Development/test environments
  #   - Temporary tables
  #
  # TERRAFORM BEHAVIOR:
  #   With deletion protection ON, 'terraform destroy' will fail.
  #   You must manually disable it first, then run destroy again.
  # --------------------------------------------------------------------------
  deletion_protection_enabled = each.value.deletion_protection_enabled

  # --------------------------------------------------------------------------
  # On-Demand Throughput Limits (Cost Control)
  # --------------------------------------------------------------------------
  # WHAT THIS IS:
  #   Sets maximum limits for on-demand (PAY_PER_REQUEST) tables.
  #
  # WHY LIMIT THROUGHPUT?
  #   Prevents unexpected costs from traffic spikes or runaway queries.
  #
  # HOW IT WORKS:
  #   - max_read_request_units: Maximum reads per second
  #   - max_write_request_units: Maximum writes per second
  #   - Once limit is reached, requests are throttled (rejected)
  #
  # WHEN TO USE:
  #   - You want cost predictability
  #   - You have known maximum traffic patterns
  #
  # WHEN NOT TO USE:
  #   - You need unlimited scaling (leave this block out)
  #   - You're using PROVISIONED billing mode (doesn't apply)
  #
  # TERRAFORM CONCEPT - dynamic block with null check:
  #   This only creates the block if on_demand_throughput is provided.
  #   If null, no limits are set (unlimited scaling).
  # --------------------------------------------------------------------------
  dynamic "on_demand_throughput" {
    # Create block only if on_demand_throughput is configured
    for_each = each.value.on_demand_throughput != null ? [each.value.on_demand_throughput] : []

    content {
      max_read_request_units  = on_demand_throughput.value.max_read_request_units
      max_write_request_units = on_demand_throughput.value.max_write_request_units
    }
  }

  # --------------------------------------------------------------------------
  # Resource Tags (Organization & Cost Tracking)
  # --------------------------------------------------------------------------
  # WHAT ARE TAGS?
  #   Key-value pairs attached to AWS resources for organization.
  #
  # WHY TAG RESOURCES?
  #   - Track costs by project, team, or environment
  #   - Find resources easily in the AWS console
  #   - Automate operations (e.g., "delete all dev resources")
  #   - Required for many compliance frameworks
  #
  # HOW THIS WORKS:
  #   merge() combines two maps of tags:
  #   1. var.tags: Common tags shared across all resources
  #   2. Table-specific tags (Name, Table)
  #
  # EXAMPLE RESULT:
  #   {
  #     "Project" = "myapp"           (from var.tags)
  #     "Environment" = "prod"        (from var.tags)
  #     "Name" = "myapp-prod-users"   (table-specific)
  #     "Table" = "users"             (table-specific)
  #   }
  #
  # BEST PRACTICES:
  #   - Always include: Environment, Project, Owner
  #   - Use consistent tag names across your organization
  #   - Automate tagging (don't rely on manual entry)
  # --------------------------------------------------------------------------
  tags = merge(var.tags, {
    Name  = "${var.project}-${var.environment}-${each.key}" # Human-readable name
    Table = each.key                                        # Original table name
  })
}