variable "table_name" {
  type    = string
  default = "introspect-claims"
}

variable "hash_key" {
  type    = string
  default = "claimId"
}

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "tags" {
  type    = map(string)
  default = {}
}
