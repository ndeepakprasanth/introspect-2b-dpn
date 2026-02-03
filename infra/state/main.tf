terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.bucket_name
  acl    = "private"
  versioning {
    enabled = true
  }
  tags = {
    Name = "${var.bucket_name}"
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "LockID"
    type = "S"
  }
  hash_key = "LockID"
}

output "bucket" {
  value = aws_s3_bucket.tf_state.id
}

output "dynamodb_table" {
  value = aws_dynamodb_table.tf_lock.name
}
