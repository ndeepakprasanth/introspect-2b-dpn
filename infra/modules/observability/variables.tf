variable "api_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 7
}
