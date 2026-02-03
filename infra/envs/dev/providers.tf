terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region for this environment"
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}
