# ==============================================================================
# DynamoDB Module Input Variables
# ==============================================================================
# PURPOSE:
#   Variables are Terraform's way of accepting input parameters.
#   They make modules reusable by allowing different configurations.
#
# WHAT ARE VARIABLES?
#   Think of variables as function parameters. When you use this module,
#   you pass values for these variables to customize the tables it creates.
#
# WHY USE VARIABLES?
#   1. Reusability: Same module code creates dev, staging, and prod resources
#   2. Flexibility: Users can configure without modifying module code
#   3. Type Safety: Terraform validates inputs match expected types
#   4. Documentation: Descriptions explain what each variable does
#
# HOW VARIABLES ARE USED:
#   When calling this module from another configuration:
#   
#   module "dynamodb" {
#     source      = "./modules/dynamodb"
#     project     = "myapp"           # <- Passing values to variables
#     environment = "prod"
#     tables      = { ... }
#   }
#
# VARIABLE STRUCTURE:
#   variable "name" {
#     description = "Human-readable explanation"  # Always include this!
#     type        = type_specification            # What kind of data?
#     default     = default_value                 # Optional - value if not provided
#     sensitive   = true/false                    # Optional - hide in logs?
#     validation  = { ... }                       # Optional - custom validation rules
#   }
# ==============================================================================

# ------------------------------------------------------------------------------
# VARIABLE: project
# ------------------------------------------------------------------------------
variable "project" {
  description = "Project name (used in resource naming: {project}-{environment}-{resource})"
  type        = string
  # No default = REQUIRED input (Terraform will error if not provided)
}

# ------------------------------------------------------------------------------
# VARIABLE: environment
# ------------------------------------------------------------------------------
variable "environment" {
  description = "Environment name (dev, staging, main) - used in resource naming and tagging"
  type        = string
  # No default = REQUIRED input
}

# ------------------------------------------------------------------------------
# VARIABLE: tables
# ------------------------------------------------------------------------------
# WHAT THIS IS:
#   A map (dictionary) that defines all the DynamoDB tables to create.
#   This is the main configuration variable for this module.
#
# TERRAFORM TYPE EXPLAINED - map(object({...})):
#   This is a complex type. Let's break it down:
#   
#   1. map(...) = A collection of key-value pairs
#      Keys are table names: "users", "orders", "logs"
#      Values are objects with table configuration
#   
#   2. object({...}) = A structured data type with named fields
#      Each object must have ALL the fields defined below
#
# REAL-WORLD EXAMPLE:
#   tables = {
#     users = {                               # Key = logical table name
#       billing_mode = "PAY_PER_REQUEST"
#       table_class  = "STANDARD"
#       hash_key     = "user_id"
#       range_key    = null
#       attributes = [
#         { name = "user_id", type = "S" }
#       ]
#       deletion_protection_enabled = true
#       ttl_attribute = "expires_at"
#       on_demand_throughput = null
#     }
#     orders = {                              # Another table
#       billing_mode = "PAY_PER_REQUEST"
#       # ... configuration for orders table
#     }
#   }
#
# WHY USE A MAP INSTEAD OF SEPARATE VARIABLES?
#   - Can create any number of tables without changing module code
#   - Each table can have different settings
#   - Easy to add/remove tables
#   - Keeps related configuration together
#
# DEFAULT VALUE EXPLAINED:
#   default = {} means if you don't provide 'tables', it creates an empty map.
#   Result: No tables are created (module does nothing).
#   This is useful for conditional deployments.
# ------------------------------------------------------------------------------
variable "tables" {
  description = "Map of DynamoDB tables to create (key = table name, value = table configuration)"

  # Complex type definition - each table must have this structure:
  type = map(object({

    # ------------------------------------------------------------------------
    # FIELD: billing_mode
    # ------------------------------------------------------------------------
    # HOW YOU PAY FOR THE TABLE:
    #   "PAY_PER_REQUEST" = On-demand, pay for each read/write (recommended for beginners)
    #   "PROVISIONED"     = Pre-specify capacity, lower cost for steady traffic
    #
    # WHEN TO USE EACH:
    #   PAY_PER_REQUEST:
    #     - Unpredictable traffic patterns
    #     - New applications without traffic history
    #     - Sporadic or bursty workloads
    #     - Simplicity (no capacity planning)
    #
    #   PROVISIONED:
    #     - Steady, predictable traffic
    #     - High-volume applications
    #     - Cost optimization for known workloads
    #     - Can save 20-40% on costs if traffic is stable
    # ------------------------------------------------------------------------
    billing_mode = string

    # ------------------------------------------------------------------------
    # FIELD: table_class
    # ------------------------------------------------------------------------
    # STORAGE TIER FOR COST OPTIMIZATION:
    #   "STANDARD"                    = Default, for frequently accessed data
    #   "STANDARD_INFREQUENT_ACCESS"  = 50% cheaper storage, for rarely accessed data
    #
    # WHEN TO USE INFREQUENT ACCESS:
    #   - Data accessed less than once per month
    #   - Archive or historical data
    #   - Backup tables
    #   - Cost savings on storage-heavy, low-access tables
    #
    # COST COMPARISON EXAMPLE:
    #   10 GB of data, accessed 100 times/month:
    #   - STANDARD: ~$2.50 storage + $0.25 reads = $2.75/month
    #   - INFREQUENT_ACCESS: ~$1.25 storage + $0.31 reads = $1.56/month
    #   Savings: $1.19/month (43% cheaper)
    # ------------------------------------------------------------------------
    table_class = string

    # ------------------------------------------------------------------------
    # FIELD: hash_key (Partition Key)
    # ------------------------------------------------------------------------
    # THE PRIMARY IDENTIFIER FOR YOUR DATA:
    #   Every item (row) in DynamoDB MUST have this key.
    #   DynamoDB uses this to distribute data across servers.
    #
    # CHOOSING A GOOD HASH KEY:
    #   ✅ High cardinality (many unique values)
    #   ✅ Evenly distributed access patterns
    #   ✅ Natural identifier from your domain
    #   
    #   ❌ Low cardinality (few unique values)
    #   ❌ Hot keys (one value accessed much more than others)
    #   ❌ Sequential values (like timestamps)
    #
    # EXAMPLES:
    #   Good: user_id, email, order_id, session_id
    #   Bad: status (only 3-4 values), date (causes hot partitions)
    #
    # VALUE MUST MATCH:
    #   Must be one of the attribute names defined in 'attributes' list below.
    # ------------------------------------------------------------------------
    hash_key = string

    # ------------------------------------------------------------------------
    # FIELD: range_key (Sort Key)
    # ------------------------------------------------------------------------
    # OPTIONAL SECONDARY IDENTIFIER:
    #   Used to sort items that share the same hash_key.
    #   Enables range queries within a partition.
    #
    # WHEN TO USE A RANGE KEY:
    #   - You need to sort data within a partition
    #   - You want to query ranges (e.g., dates between X and Y)
    #   - You have multiple items per hash_key
    #
    # WHEN NOT TO USE:
    #   - Simple key-value lookups
    #   - Each hash_key value appears only once
    #   - No sorting or range queries needed
    #
    # REAL-WORLD EXAMPLE:
    #   User orders table:
    #   - hash_key = "user_id"    (groups orders by user)
    #   - range_key = "order_date" (sorts orders chronologically)
    #   
    #   This enables queries like:
    #   "Get all orders for user123 between Jan 1 and Jan 31"
    #
    # NULL VALUE:
    #   Set to null if you don't need a range key (simple hash-only table).
    #
    # VALUE MUST MATCH:
    #   Must be one of the attribute names in 'attributes', or null.
    # ------------------------------------------------------------------------
    range_key = string

    # ------------------------------------------------------------------------
    # FIELD: attributes
    # ------------------------------------------------------------------------
    # ATTRIBUTE DEFINITIONS FOR KEYS AND INDEXES:
    #   Defines the data type for attributes used in keys.
    #
    # IMPORTANT - SCHEMA-LESS DATABASE:
    #   DynamoDB is schema-less! You do NOT need to define every attribute here.
    #   Only define attributes used in:
    #   - Primary key (hash_key, range_key)
    #   - Global Secondary Indexes (GSI)
    #   - Local Secondary Indexes (LSI)
    #
    # TYPE SPECIFICATION:
    #   This is a list of objects. Each object defines one attribute.
    #   list(object({...})) = an ordered collection of structured objects
    #
    # STRUCTURE:
    #   attributes = [
    #     { name = "user_id",    type = "S" },  # String
    #     { name = "created_at", type = "N" },  # Number
    #   ]
    #
    # ATTRIBUTE TYPES:
    #   "S" = String  (text data)
    #   "N" = Number  (integers and decimals, stored as strings internally)
    #   "B" = Binary  (images, files, encrypted data)
    #
    # EXAMPLES BY USE CASE:
    #   User IDs: type = "S"
    #   Email addresses: type = "S"
    #   Timestamps (Unix epoch): type = "N"
    #   Prices/quantities: type = "N"
    #   Profile pictures: type = "B"
    #
    # COMMON BEGINNER MISTAKE:
    #   ❌ Don't define all your data attributes here
    #   ✅ Only define attributes used in keys/indexes
    #
    #   You can store 100 attributes in each item, but only define
    #   the 2-3 used in your keys here!
    # ------------------------------------------------------------------------
    attributes = list(object({
      name = string # Attribute name (e.g., "user_id")
      type = string # Data type: "S" (string), "N" (number), or "B" (binary)
    }))

    # ------------------------------------------------------------------------
    # FIELD: deletion_protection_enabled
    # ------------------------------------------------------------------------
    # SAFETY FEATURE - PREVENTS ACCIDENTAL TABLE DELETION:
    #   If true, you cannot delete the table until you manually disable
    #   this protection first. Requires two separate actions to delete.
    #
    # TYPE: bool (boolean)
    #   Can only be true or false (no quotes needed in Terraform)
    #
    # WHEN TO SET TRUE:
    #   ✅ Production databases
    #   ✅ Tables with critical business data
    #   ✅ Tables that should never be deleted
    #   ✅ Compliance requirements
    #
    # WHEN TO SET FALSE:
    #   ✅ Development/test environments
    #   ✅ Temporary tables
    #   ✅ CI/CD pipelines (need to tear down and recreate)
    #
    # TERRAFORM BEHAVIOR:
    #   With deletion_protection_enabled = true:
    #   - 'terraform destroy' will FAIL
    #   - You must manually disable protection in AWS console first
    #   - Or update this to false, apply, then destroy
    #
    # BEST PRACTICE BY ENVIRONMENT:
    #   dev:     false (easier testing and cleanup)
    #   staging: true  (protect from accidents)
    #   prod:    true  (always protect production data!)
    #
    # REAL-WORLD STORY:
    #   This feature has saved countless databases from accidental deletion
    #   during refactoring or cleanup scripts. Always enable for production!
    # ------------------------------------------------------------------------
    deletion_protection_enabled = bool

    # ------------------------------------------------------------------------
    # FIELD: ttl_attribute
    # ------------------------------------------------------------------------
    # TIME TO LIVE - AUTOMATIC DATA EXPIRATION:
    #   Name of the attribute that stores expiration timestamps.
    #   DynamoDB automatically deletes items when this timestamp passes.
    #
    # TYPE: string
    #   The name of an attribute in your items (must be type N - number)
    #
    # HOW IT WORKS:
    #   1. Add a number attribute to items (Unix timestamp)
    #   2. Set ttl_attribute to that attribute's name
    #   3. DynamoDB checks periodically (every ~48 hours)
    #   4. Items with past timestamps are automatically deleted
    #
    # TIMESTAMP FORMAT:
    #   Must be Unix epoch time (seconds since Jan 1, 1970)
    #   Example: 1703289600 = December 23, 2023 00:00:00 UTC
    #
    # EXAMPLE USAGE:
    #   Table item:
    #   {
    #     "session_id": "abc123",
    #     "expires_at": 1703289600,  # Unix timestamp
    #     "user_data": "..."
    #   }
    #   
    #   ttl_attribute = "expires_at"
    #   Result: Item deleted automatically after Dec 23, 2023
    #
    # COST BENEFIT:
    #   TTL deletions are FREE! No charge for these delete operations.
    #   Compare to manually deleting (you pay per delete request).
    #
    # USE CASES:
    #   - Session data (expire after hours/days)
    #   - Temporary tokens (expire after use)
    #   - Cache data (expire after freshness window)
    #   - Log data (retain for 30/90 days, then auto-delete)
    #   - Event data (compliance-required retention periods)
    #
    # NULL VALUE:
    #   Set to null if you don't want automatic expiration.
    #   The table will keep all data indefinitely (normal behavior).
    #
    # DELETION TIMING:
    #   - Not instant! Can take up to 48 hours after expiration
    #   - Don't rely on TTL for real-time deletions
    #   - Your application should still check if data is expired
    # ------------------------------------------------------------------------
    ttl_attribute = string

    # ------------------------------------------------------------------------
    # FIELD: point_in_time_recovery_enabled
    # ------------------------------------------------------------------------
    # DISASTER RECOVERY - CONTINUOUS BACKUP FEATURE:
    #   Enables Point-in-Time Recovery (PITR) for the table.
    #   PITR provides continuous backups of DynamoDB data.
    #
    # TYPE: bool (boolean)
    #   true = Enable PITR (recommended for production)
    #   false = Disable PITR (development/cost-saving)
    #
    # HOW IT WORKS:
    #   - AWS automatically backs up your table continuously
    #   - You can restore to any second within the last 35 days
    #   - Backups are incremental (only changes are stored)
    #   - No performance impact on your table
    #
    # RECOVERY CAPABILITIES:
    #   - RPO (Recovery Point Objective): ~5 minutes
    #   - Restore to any point in the last 35 days
    #   - Restore creates a NEW table (original stays intact)
    #   - All table data, indexes, and encryption settings preserved
    #
    # COST:
    #   ~20% additional storage cost of your table size
    #   Example: 10 GB table = ~$0.50/month for PITR
    #
    # WHEN TO ENABLE (true):
    #   ✅ Production environments
    #   ✅ Tables with critical business data
    #   ✅ Data that would be hard/impossible to recreate
    #   ✅ Compliance requirements (many require backup capability)
    #
    # WHEN TO DISABLE (false):
    #   ✅ Development environments (save costs)
    #   ✅ Ephemeral data that can be recreated
    #   ✅ Tables used only for caching
    #
    # BEST PRACTICE BY ENVIRONMENT:
    #   dev:     false (save costs)
    #   staging: true  (test backup/restore procedures)
    #   prod:    true  (ALWAYS enable for production!)
    # ------------------------------------------------------------------------
    point_in_time_recovery_enabled = bool

    # ------------------------------------------------------------------------
    # FIELD: on_demand_throughput
    # ------------------------------------------------------------------------
    # COST CONTROL FOR ON-DEMAND TABLES:
    #   Sets maximum read/write capacity to prevent runaway costs.
    #
    # TYPE: object (structured data with two fields)
    #   Either provide both max values, or set entire field to null.
    #
    # WHEN THIS APPLIES:
    #   Only used when billing_mode = "PAY_PER_REQUEST"
    #   Ignored if billing_mode = "PROVISIONED"
    #
    # WHY LIMIT THROUGHPUT?
    #   On-demand tables scale automatically (great!), but this means:
    #   - A bug could cause millions of requests = huge bill
    #   - A traffic spike could exceed your budget
    #   - No cost protection by default
    #
    #   Setting limits prevents cost disasters while keeping auto-scaling.
    #
    # HOW IT WORKS:
    #   - max_read_request_units: Maximum reads per second
    #   - max_write_request_units: Maximum writes per second
    #   - When limit reached, requests are throttled (HTTP 400 error)
    #
    # REQUEST UNIT CALCULATION:
    #   1 Read Request Unit (RRU) = 4 KB of data
    #   1 Write Request Unit (WRU) = 1 KB of data
    #   
    #   Example: Reading a 12 KB item = 3 RRUs
    #
    # EXAMPLE CONFIGURATION:
    #   on_demand_throughput = {
    #     max_read_request_units  = 10000   # Max 10,000 reads/second
    #     max_write_request_units = 5000    # Max 5,000 writes/second
    #   }
    #   
    #   This limits costs to approximately:
    #   Reads:  10,000 * $0.25 / 1M * 2.6M requests/month = ~$6.50/month
    #   Writes: 5,000  * $1.25 / 1M * 2.6M requests/month = ~$16.25/month
    #
    # NULL VALUE:
    #   Set to null for unlimited throughput (default on-demand behavior).
    #   Use this when you need true auto-scaling without limits.
    #
    # BEST PRACTICE:
    #   Development: Set limits to prevent accidental costs
    #   Production: Start with limits, remove after traffic patterns are known
    #
    # TERRAFORM TYPE DETAIL:
    #   object({...}) means if you provide this field, you MUST provide
    #   both max_read_request_units AND max_write_request_units.
    #   Can't provide just one.
    # ------------------------------------------------------------------------
    on_demand_throughput = object({
      max_read_request_units  = number # Maximum reads per second
      max_write_request_units = number # Maximum writes per second
    })
  }))

  # Default value: empty map = no tables created
  # This makes the 'tables' variable optional
  default = {}
}

# ------------------------------------------------------------------------------
# VARIABLE: tags
# ------------------------------------------------------------------------------
# WHAT THIS IS:
#   Common tags to apply to all resources created by this module.
#
# WHAT ARE TAGS?
#   Tags are key-value pairs attached to AWS resources for organization.
#   They're like labels you put on resources to categorize and track them.
#
# TYPE EXPLAINED - map(string):
#   A collection of key-value pairs where both keys and values are strings.
#   Example: { "Environment" = "prod", "Team" = "backend" }
#
# HOW TAGS ARE USED:
#   1. Cost Tracking: See how much each project/team spends
#   2. Organization: Find all resources for a specific project
#   3. Automation: Scripts can filter resources by tags
#   4. Access Control: IAM policies can use tags for permissions
#   5. Compliance: Required for many regulatory frameworks
#
# EXAMPLE USAGE:
#   tags = {
#     "Project"     = "myapp"
#     "Environment" = "production"
#     "Team"        = "backend-team"
#     "Owner"       = "john@example.com"
#     "CostCenter"  = "engineering"
#     "Compliance"  = "HIPAA"
#   }
#
# TAG BEST PRACTICES:
#   ✅ Use consistent naming across organization (PascalCase or snake_case)
#   ✅ Always include: Environment, Project, Owner
#   ✅ Add business-specific tags: CostCenter, Department
#   ✅ Use automation - don't rely on manual tagging
#   
#   ❌ Don't use sensitive data in tags (they're visible to many users)
#   ❌ Don't use special characters (stick to letters, numbers, spaces)
#
# MODULE BEHAVIOR:
#   These tags are merged with table-specific tags in main.tf.
#   Table-specific tags override common tags if there's a conflict.
#
# DEFAULT VALUE:
#   default = {} means tags are optional. If not provided, tables will
#   only have the table-specific tags (Name, Table).
#
# COST ALLOCATION TAGS:
#   In AWS Cost Explorer, you can enable tags for cost reporting.
#   This lets you see: "How much did the backend team spend this month?"
# ------------------------------------------------------------------------------
variable "tags" {
  description = "Common resource tags to apply to all resources (map of key-value pairs)"
  type        = map(string)

  # Default: empty map = no common tags
  # Table-specific tags (Name, Table) are still added in main.tf
  default = {}
}
