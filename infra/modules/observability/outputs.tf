output "api_log_group_arn" {
  value = aws_cloudwatch_log_group.api_gateway.arn
}

output "eks_log_group_arn" {
  value = aws_cloudwatch_log_group.eks_cluster.arn
}

output "app_log_group_arn" {
  value = aws_cloudwatch_log_group.application.arn
}
