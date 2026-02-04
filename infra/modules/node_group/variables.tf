variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_group_name" {
  type    = string
  default = "demo-node-group"
}

variable "desired_size" {
  type    = number
  default = 1
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}
