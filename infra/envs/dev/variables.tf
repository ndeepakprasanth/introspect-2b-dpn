# place any env-specific variable defaults here

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "code_connection_arn" {
  type    = string
  default = ""
}

variable "pipeline_artifact_bucket" {
  type    = string
  default = ""
}
