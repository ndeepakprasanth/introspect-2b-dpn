output "bucket_name" {
  value       = aws_s3_bucket.notes.bucket
  description = "S3 bucket name for claim notes"
}

output "bucket" {
  value       = aws_s3_bucket.notes.bucket
  description = "S3 bucket name for claim notes"
}
