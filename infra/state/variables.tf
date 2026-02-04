variable "bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-locks"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
