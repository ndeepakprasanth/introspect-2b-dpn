output "table_name" {
  value       = aws_dynamodb_table.claims.name
  description = "DynamoDB table name for claims"
}

output "table_arn" {
  value       = aws_dynamodb_table.claims.arn
  description = "DynamoDB table ARN"
}
