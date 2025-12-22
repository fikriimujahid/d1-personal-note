output "table_name" {
  description = "Map of DynamoDB table names created by this module (keyed by table logical name)"
  value = { for k, t in aws_dynamodb_table.main : k => t.name }
}

output "table_arn" {
  description = "Map of DynamoDB table ARNs created by this module (keyed by table logical name)"
  value = { for k, t in aws_dynamodb_table.main : k => t.arn }
}