#!/usr/bin/env bash
set -e

AWS_PROFILE=${AWS_PROFILE:-Deepak}
AWS_REGION=${AWS_REGION:-us-east-1}
TF_STATE_BUCKET=${TF_STATE_BUCKET:-}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              🧹 Destroy All Resources                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  WARNING: This will delete ALL resources!"
echo ""
echo "AWS Profile: $AWS_PROFILE"
echo "AWS Region: $AWS_REGION"
echo ""

read -p "Are you sure you want to destroy everything? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Destroy cancelled"
  exit 0
fi

echo ""
echo "=== Step 1: Delete Kubernetes Resources ==="
kubectl delete namespace app --ignore-not-found=true
echo "✅ Kubernetes resources deleted"

echo ""
echo "=== Step 2: Destroy Terraform Infrastructure ==="
cd infra/envs/dev

if [[ -z "$TF_STATE_BUCKET" ]]; then
  echo "⚠️  TF_STATE_BUCKET not set. Trying to detect from terraform output..."
  TF_STATE_BUCKET=$(terraform output -raw s3_notes_bucket 2>/dev/null | cut -d'-' -f1-4 || echo "")
fi

if [[ -n "$TF_STATE_BUCKET" ]]; then
  terraform init -backend-config="bucket=$TF_STATE_BUCKET" \
    -backend-config="key=instrospect2/dev/terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=terraform-locks" || true
fi

terraform destroy -auto-approve
cd ../../..
echo "✅ Infrastructure destroyed"

echo ""
echo "=== Step 3: Delete S3 State Bucket (Optional) ==="
if [[ -n "$TF_STATE_BUCKET" ]]; then
  read -p "Delete S3 state bucket $TF_STATE_BUCKET? (yes/no): " delete_bucket
  if [[ "$delete_bucket" == "yes" ]]; then
    echo "Attempting to delete S3 bucket..."
    aws s3 rm s3://$TF_STATE_BUCKET --recursive --profile $AWS_PROFILE 2>/dev/null || echo "⚠️  Could not empty bucket (may not exist or no permissions)"
    aws s3 rb s3://$TF_STATE_BUCKET --profile $AWS_PROFILE 2>/dev/null && echo "✅ S3 state bucket deleted" || echo "⚠️  Could not delete bucket (may not exist or no permissions)"
  else
    echo "⏭️  S3 state bucket kept"
  fi
else
  echo "⏭️  No state bucket specified, skipping"
fi

echo ""
echo "=== Step 4: Delete DynamoDB Lock Table (Optional) ==="
read -p "Delete DynamoDB lock table 'terraform-locks'? (yes/no): " delete_table
if [[ "$delete_table" == "yes" ]]; then
  aws dynamodb delete-table --table-name terraform-locks --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null && echo "✅ DynamoDB lock table deleted" || echo "⚠️  Table not found or already deleted"
else
  echo "⏭️  DynamoDB lock table kept"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              ✅ Destroy Complete                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "All resources have been destroyed."
echo ""
