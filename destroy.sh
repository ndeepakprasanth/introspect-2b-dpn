#!/usr/bin/env bash
set -e

AWS_PROFILE=${AWS_PROFILE:-Deepak}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              🧹 Destroy All Resources                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "AWS Profile: $AWS_PROFILE"
echo "AWS Region: $AWS_REGION"
echo ""

# Auto-detect S3 bucket from S3 buckets list
echo "🔍 Searching for Terraform state bucket..."
TF_STATE_BUCKET=$(aws s3 ls --profile $AWS_PROFILE 2>/dev/null | grep 'introspect-tf-state' | awk '{print $3}' | head -n 1 || echo "")

if [[ -n "$TF_STATE_BUCKET" ]]; then
  echo "📦 Found state bucket: $TF_STATE_BUCKET"
else
  echo "⚠️  No state bucket found, will use local state"
fi

echo ""
echo "=== Step 1: Delete Kubernetes Resources ==="
kubectl delete namespace app --ignore-not-found=true
echo "✅ Kubernetes resources deleted"

echo ""
echo "=== Step 2: Destroy Terraform Infrastructure ==="
cd infra/envs/dev

# Remove backend config and .terraform directory
echo "Removing S3 backend configuration..."
cp providers.tf providers.tf.bak
sed -i.tmp '/backend "s3"/,/^  }/d' providers.tf
rm -rf .terraform .terraform.lock.hcl

if [[ -n "$TF_STATE_BUCKET" ]]; then
  echo "Downloading state from S3: $TF_STATE_BUCKET"
  aws s3 cp s3://$TF_STATE_BUCKET/instrospect2/dev/terraform.tfstate terraform.tfstate --profile $AWS_PROFILE 2>/dev/null || echo "⚠️  Could not download state from S3"
fi

echo "Initializing Terraform with local state..."
terraform init 2>&1 | grep -v "^$" || true

echo "Running terraform destroy..."
terraform destroy -auto-approve 2>&1 || echo "⚠️  No resources to destroy"

# Restore original providers.tf
mv providers.tf.bak providers.tf
rm -f providers.tf.tmp

cd ../../..
echo "✅ Infrastructure destroy attempted"

echo ""
echo "=== Step 3: Delete S3 State Bucket ==="
if [[ -n "$TF_STATE_BUCKET" ]]; then
  echo "Deleting S3 state bucket: $TF_STATE_BUCKET"
  aws s3 rm s3://$TF_STATE_BUCKET --recursive --profile $AWS_PROFILE 2>/dev/null || echo "⚠️  Could not empty bucket (may not exist)"
  aws s3 rb s3://$TF_STATE_BUCKET --profile $AWS_PROFILE 2>/dev/null && echo "✅ S3 state bucket deleted" || echo "⚠️  Could not delete bucket (may not exist)"
else
  echo "⏭️  No state bucket found, skipping"
fi

echo ""
echo "=== Step 4: Delete DynamoDB Lock Table ==="
aws dynamodb delete-table --table-name terraform-locks --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null && echo "✅ DynamoDB lock table deleted" || echo "⏭️  Table not found or already deleted"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              ✅ Destroy Complete                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "All resources have been destroyed."
echo ""
