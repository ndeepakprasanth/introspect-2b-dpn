module "vpc" {
  source = "../../modules/vpc"
  name   = "introspect-dev-vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source       = "../../modules/eks"
  cluster_name = "introspect-dpn-eks"
  # Use the existing cluster subnets (these belong to the cluster's VPC). Do not
  # point at the new VPC created by the local vpc module otherwise terraform
  # will attempt to replace cluster/fargate resources with incompatible subnets.
  subnet_ids   = ["subnet-0c4eabd3efffbcd13", "subnet-092ae6252e5fd8541"]
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "introspect-sample-service"
}

module "node_group" {
  source        = "../../modules/node_group"
  # prefer exported cluster output if present
  cluster_name  = module.eks.cluster_name != null ? module.eks.cluster_name : "introspect-dpn-eks"
  # use the same subnets used by the cluster (existing cluster subnets)
  subnet_ids    = ["subnet-0c4eabd3efffbcd13", "subnet-092ae6252e5fd8541"]
  node_group_name = "demo-node-group"
  desired_size  = 1
  min_size      = 1
  max_size      = 2
  instance_types = ["t3.small"]
}

# Example (commented): create an IAM role for the sample-service service account to invoke Bedrock via IRSA.
# Uncomment and adapt the values (especially cluster name or provider URL) when you want to enable IRSA.

# data "aws_eks_cluster" "cluster" {
#   name = module.eks.cluster_name != null ? module.eks.cluster_name : "introspect-dpn-eks"
# }
#
# data "aws_iam_openid_connect_provider" "eks_oidc" {
#   url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
# }
#
# module "bedrock_iam" {
#   source = "../../modules/iam"
#   sa_namespace = "default"
#   sa_name = "sample-service"
#   oidc_provider_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
#   oidc_provider_arn = data.aws_iam_openid_connect_provider.eks_oidc.arn
#   tags = {
#     Environment = "dev"
#   }
# }
