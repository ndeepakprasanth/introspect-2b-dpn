variable "project_name" {
  type = string
}

variable "pipeline_name" {
  type = string
}

variable "repository" {
  type        = string
  description = "GitHub full repo id: owner/repo"
}

variable "branch" {
  type    = string
  default = "main"
}

variable "connection_arn" {
  type    = string
  default = ""
}

variable "artifact_bucket" {
  type = string
}

variable "buildspec" {
  type    = string
  default = "buildspec.yml"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
