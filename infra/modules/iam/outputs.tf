output "role_arn" {
  value       = aws_iam_role.bedrock_sa_role.arn
  description = "ARN of the IAM role to be used with the service account (IRSA)"
}

output "policy_arn" {
  value       = aws_iam_policy.bedrock_invoke_policy.arn
  description = "ARN of the Bedrock invoke policy"
}

output "role_name" {
  value       = aws_iam_role.bedrock_sa_role.name
  description = "Name of the IAM role created for Bedrock access"
}
