output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "api_endpoint" {
  value = module.api_gateway.api_endpoint
}

output "nlb_dns_name" {
  value = module.nlb.nlb_dns_name
}

output "bedrock_role_arn" {
  value = module.bedrock_iam.role_arn
}

output "s3_notes_bucket" {
  value = module.s3_notes.bucket_name
}

output "dynamodb_table" {
  value = module.dynamodb_claims.table_name
}
