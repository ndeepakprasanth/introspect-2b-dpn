variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS"
  type        = list(string)
}
variable "enable_fargate" {
  description = "Enable EKS Fargate (must be false for EC2-only lab)"
  type        = bool
  default     = false
}
