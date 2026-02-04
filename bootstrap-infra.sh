#!/usr/bin/env bash
set -euo pipefail

# bootstrap-infra.sh
# Simple, idempotent bootstrap to create S3 backend + DynamoDB lock and run Terraform for the single environment (infra/envs/dev)

TF_STATE_BUCKET=${TF_STATE_BUCKET:-}
TF_STATE_KEY=${TF_STATE_KEY:-instrospect2/dev/terraform.tfstate}
DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-locks}
AWS_REGION=${AWS_REGION:-us-east-1}

usage() {
  cat <<EOF
Usage: TF_STATE_BUCKET=my-bucket [TF_STATE_KEY=path/to/state] [AWS_REGION=region] ./bootstrap-infra.sh

This script will:
- Create the S3 bucket (if missing) and enable versioning
- Create the DynamoDB table for locking (if missing)
- Run terraform init with backend configured and terraform apply in infra/envs/dev

Notes:
- Requires AWS CLI and Terraform installed and configured with appropriate credentials.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

command -v aws >/dev/null 2>&1 || { echo "aws CLI required. Install and configure it first." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "terraform required. Install it first." >&2; exit 1; }

# Ensure AWS credentials work
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials not configured or invalid. Set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or use a configured profile." >&2
  exit 1
fi

# Prompt for bucket if not supplied
if [[ -z "$TF_STATE_BUCKET" ]]; then
  read -rp "Enter Terraform state S3 bucket name to create/use: " TF_STATE_BUCKET
  if [[ -z "$TF_STATE_BUCKET" ]]; then
    echo "Bucket name is required." >&2
    exit 1
  fi
fi

echo "Using bucket: $TF_STATE_BUCKET"

# Create bucket if it doesn't exist
if ! aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
  echo "Creating S3 bucket: $TF_STATE_BUCKET in region $AWS_REGION"
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --acl private
  else
    aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --create-bucket-configuration LocationConstraint=$AWS_REGION --acl private
  fi
  echo "Enabling versioning on bucket"
  aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" --versioning-configuration Status=Enabled
else
  echo "Bucket already exists: $TF_STATE_BUCKET"
fi

# Create DynamoDB table for locking if missing
if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" >/dev/null 2>&1; then
  echo "Creating DynamoDB table for locks: $DYNAMODB_TABLE"
  aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
  echo "Waiting for DynamoDB table to be active..."
  aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE"
else
  echo "DynamoDB table already exists: $DYNAMODB_TABLE"
fi

# Run terraform init & apply in infra/envs/dev
pushd infra/envs/dev >/dev/null
echo "Initializing terraform with S3 backend..."
terraform init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="key=$TF_STATE_KEY" -backend-config="region=$AWS_REGION" -backend-config="dynamodb_table=$DYNAMODB_TABLE"

echo "Planning and applying Terraform (infra/envs/dev)..."
terraform apply -auto-approve
popd >/dev/null

echo "Bootstrap complete. Terraform state stored in s3://$TF_STATE_BUCKET/$TF_STATE_KEY"
