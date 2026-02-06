terraform {
  backend "s3" {
    # Backend config provided via -backend-config flags during init
    # bucket         = "<provided-at-init>"
    # key            = "instrospect2/dev/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-locks"
  }

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
