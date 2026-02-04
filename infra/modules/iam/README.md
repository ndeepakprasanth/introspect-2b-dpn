Module: IAM helpers - Bedrock IRSA role

This module creates an IAM role and policy to allow a Kubernetes service account to invoke Amazon Bedrock models via IRSA.

Inputs
- sa_namespace: Kubernetes namespace of the service account (default: default)
- sa_name: Kubernetes service account name (default: sample-service)
- oidc_provider_url: OIDC provider URL for the EKS cluster (required)
- oidc_provider_arn: The ARN of the aws_iam_openid_connect_provider for the cluster (required)
- policy_name: Name for the IAM policy (default: bedrock-invoke-policy)
- role_name: Name for the IAM role (default: sample-service-bedrock-role)

Outputs
- role_arn: ARN of the created role
- policy_arn: ARN of the created policy
- role_name: Role name

Notes
- The policy intentionally allows bedrock actions against "*". Replace with a more restricted resource when you have model ARNs available.
- To enable IRSA, create a Kubernetes service account with the annotation:
  eks.amazonaws.com/role-arn: <role-arn>

Example usage (see infra/envs/dev/main.tf for a commented example):

  data "aws_eks_cluster" "cluster" {
    name = module.eks.cluster_name
  }

  data "aws_iam_openid_connect_provider" "eks_oidc" {
    url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  }

  module "bedrock_iam" {
    source = "../../modules/iam"
    sa_namespace = "default"
    sa_name = "sample-service"
    oidc_provider_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
    oidc_provider_arn = data.aws_iam_openid_connect_provider.eks_oidc.arn
  }
