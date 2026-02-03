variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of AZs to create subnets in"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
