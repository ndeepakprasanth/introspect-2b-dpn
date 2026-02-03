# Infra state stack

This folder provisions the S3 bucket and DynamoDB table used for Terraform remote state locking.

If the S3 bucket or DynamoDB table already exist, import them into this stack:

1. Configure AWS profile (example uses `Deepak`):
   export AWS_PROFILE=Deepak
2. Initialize:
   terraform init
3. Import existing resources:
   terraform import aws_s3_bucket.tf_state instrospect2b-dpn-state-bucket
   terraform import aws_dynamodb_table.tf_lock terraform-locks
4. Apply:
   terraform apply -var "bucket_name=instrospect2b-dpn-state-bucket" -auto-approve

If you prefer the bootstrap script, it already created the S3 bucket and DynamoDB table for you.
