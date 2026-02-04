variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS"
  type        = list(string)
}
