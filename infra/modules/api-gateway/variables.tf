variable "api_name" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "nlb_listener_arn" {
  type = string
}

variable "cloudwatch_log_group_arn" {
  type = string
}
