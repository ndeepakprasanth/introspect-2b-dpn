# Example S3 backend configuration (commented).
# To enable S3 remote state, either uncomment and populate the values below
# or run `terraform init -backend-config="bucket=..." -backend-config="key=..." -backend-config="region=..."`.

# backend "s3" {
#   bucket         = "my-terraform-state-bucket"
#   key            = "instrospect2/dev/terraform.tfstate"
#   region         = "us-east-1"
#   dynamodb_table = "terraform-locks" # optional but recommended for state locking
#   encrypt        = true
# }

# Notes:
# 1. Create the S3 bucket and (optionally) the DynamoDB table for locking before running `terraform init` with backend-config.
# 2. Recommended bucket policy: deny public access and enable versioning for state safety.
# 3. The workflow in .github/workflows/terraform.yml uses GitHub Secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, TF_STATE_BUCKET, TF_STATE_KEY
