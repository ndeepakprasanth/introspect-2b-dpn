variable "sa_namespace" {
  type        = string
  description = "Kubernetes namespace of the service account that will assume this role"
  default     = "default"
}

variable "sa_name" {
  type        = string
  description = "Kubernetes service account name"
  default     = "sample-service"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL for the EKS cluster (e.g., https://oidc.eks.us-east-1.amazonaws.com/id/XXXXX)"
}

variable "oidc_provider_arn" {
  type        = string
  description = "IAM OIDC provider ARN corresponding to the OIDC provider URL (exposed in aws_iam_openid_connect_provider)"
}

variable "policy_name" {
  type    = string
  default = "bedrock-invoke-policy"
}

variable "role_name" {
  type    = string
  default = "sample-service-bedrock-role"
}

variable "tags" {
  type    = map(string)
  default = {}
}
