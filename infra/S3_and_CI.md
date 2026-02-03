# S3 backend and GitHub Actions (optional)

## S3 Backend (recommended for team/CI use)

To use an S3 backend with DynamoDB locking, either run `terraform init` with backend config flags or enable `infra/global/backend_s3.tf` example (it's commented by default).

Example (local):

1. Create an S3 bucket and (optionally) a DynamoDB table for locks.
2. Run:

```bash
cd infra/envs/dev
terraform init -backend-config="bucket=your-bucket" -backend-config="key=instrospect2/dev/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="dynamodb_table=terraform-locks"
```

Notes:
- Ensure the bucket has versioning enabled and public access blocked.
- Create the DynamoDB table with partition key `LockID` (string) if you plan to use locking.

## GitHub Actions workflow

A minimal workflow is provided at `.github/workflows/terraform.yml`.
- It runs `terraform plan` on pull requests that touch `infra/**`.
- It runs `terraform apply` on pushes to `main` (configure with caution).

Set these GitHub Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `TF_STATE_BUCKET`
- `TF_STATE_KEY`

Security tip: restrict the AWS credentials to least-privilege required for the Terraform actions (S3/DynamoDB/EKS/ECR/IAM as needed) and consider using GitHub Environments for required approvals before applying to `main`.

---

## Bootstrap script

A one-step idempotent bootstrap script `bootstrap-infra.sh` is provided in the repository root. It:
- creates the S3 state bucket (if missing) and enables versioning
- creates the DynamoDB table for locks (if missing)
- runs `terraform init` and `terraform apply` in `infra/envs/dev`

Usage examples:

```bash
# Interactive - you will be prompted for bucket name
./bootstrap-infra.sh

# Non-interactive
TF_STATE_BUCKET=my-bucket TF_STATE_KEY=instrospect2/dev/terraform.tfstate AWS_REGION=us-east-1 ./bootstrap-infra.sh

```