#!/usr/bin/env bash
set +e

AWS_PROFILE=${AWS_PROFILE:-Deepak}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              🧹 Destroy All Resources                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "AWS Profile: $AWS_PROFILE"
echo "AWS Region: $AWS_REGION"
echo ""

# --- helper: remove all objects, versions & delete-markers from an S3 bucket ---
empty_versioned_bucket() {
  local BKT="$1"
  local REGION="$AWS_REGION"
  local PROFILE="$AWS_PROFILE"

  # If bucket doesn't exist, nothing to do
  if ! aws s3api head-bucket --bucket "$BKT" --profile "$PROFILE" 2>/dev/null; then
    echo "⏭️  Bucket not found: $BKT (skip empty)"
    return 0
  fi

  echo "🧹 Emptying bucket (all versions): s3://$BKT"

  # Delete all object versions (paged)
  aws s3api list-object-versions --bucket "$BKT" --profile "$PROFILE" --output json \
    | jq -r '.Versions[]? | [ .Key, .VersionId ] | @tsv' 2>/dev/null \
    | while IFS=$'\t' read -r KEY VID; do
        aws s3api delete-object --bucket "$BKT" --key "$KEY" --version-id "$VID" --profile "$PROFILE" >/dev/null 2>&1 || true
      done

  # Delete all delete-markers (paged)
  aws s3api list-object-versions --bucket "$BKT" --profile "$PROFILE" --output json \
    | jq -r '.DeleteMarkers[]? | [ .Key, .VersionId ] | @tsv' 2>/dev/null \
    | while IFS=$'\t' read -r KEY VID; do
        aws s3api delete-object --bucket "$BKT" --key "$KEY" --version-id "$VID" --profile "$PROFILE" >/dev/null 2>&1 || true
      done

  # Best-effort: also run recursive rm (clears any unversioned leftovers)
  aws s3 rm "s3://$BKT" --recursive --profile "$PROFILE" >/dev/null 2>&1 || true
}

# Auto-detect S3 bucket from S3 buckets list
echo "🔍 Searching for Terraform state bucket..."
TF_STATE_BUCKET=$(aws s3 ls --profile "$AWS_PROFILE" 2>/dev/null | grep 'introspect-tf-state' | awk '{print $3}' | head -n 1 || echo "")

if [[ -n "$TF_STATE_BUCKET" ]]; then
  echo "📦 Found state bucket: $TF_STATE_BUCKET"
else
  echo "⚠️  No state bucket found, will use local state"
fi

echo ""
echo "=== Step 1: Delete Kubernetes Resources ==="
kubectl delete namespace app --ignore-not-found=true --wait=false 2>/dev/null || true
echo "✅ Kubernetes resources deleted"

echo ""
echo "=== Step 3: Manual Fallback Deletes (only if TF destroy failed) ==="
if [[ "${TF_DESTROY_OK:-0}" -eq 1 ]]; then
  echo "Skipping manual deletes because Terraform already destroyed the stack."
else
# --- K8s/Helm cleanup for resources deployed in the 'default' namespace ---
echo "Cleaning up Helm release and K8s resources in 'default' namespace..."
# Uninstall the Helm release (idempotent)
helm uninstall sample-service -n default >/dev/null 2>&1 || true

# Best-effort deletes of objects created by the chart/patches
kubectl delete svc sample-service-sample-service -n default --ignore-not-found >/dev/null 2>&1 || true
kubectl delete deploy sample-service-sample-service -n default --ignore-not-found >/dev/null 2>&1 || true
kubectl delete configmap sample-mocks -n default --ignore-not-found >/dev/null 2>&1 || true

# Give the control plane a brief moment to reconcile Service/NLB tear-down
sleep 5

# Delete EKS Node Groups first (EC2-only setup)
echo "Deleting EKS node groups..."
for NG in $(aws eks list-nodegroups --cluster-name introspect-dpn-eks --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'nodegroups[]' --output text 2>/dev/null); do
  echo "Deleting node group: $NG"
  aws eks delete-nodegroup --cluster-name introspect-dpn-eks --nodegroup-name $NG --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || true
done

# Wait for node groups to delete using AWS CLI waiters
echo "Waiting for node groups to delete (this may take a few minutes)..."

# Wait for each node group to be fully deleted
for NG in $(aws eks list-nodegroups \
  --cluster-name introspect-dpn-eks \
  --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --query 'nodegroups[]' --output text 2>/dev/null); do
  echo "Waiting for node group to delete: $NG"
  aws eks wait nodegroup-deleted \
    --cluster-name introspect-dpn-eks \
    --nodegroup-name "$NG" \
    --region "$AWS_REGION" --profile "$AWS_PROFILE" || true
done


# Delete EKS Cluster
echo "Deleting EKS cluster..."
aws eks delete-cluster --name introspect-dpn-eks --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || true

# Delete DynamoDB Tables
echo "Deleting DynamoDB tables..."
aws dynamodb delete-table --table-name introspect-claims --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || true
aws dynamodb delete-table --table-name terraform-locks --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || true

# Delete ECR Repository
echo "Deleting ECR repository..."
aws ecr delete-repository --repository-name introspect-sample-service --force --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || true

# Delete CloudWatch Log Groups
echo "Deleting CloudWatch log groups..."
for LOG_GROUP in $(aws logs describe-log-groups --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "logGroups[?contains(logGroupName, 'introspect')].logGroupName" --output text 2>/dev/null); do
  aws logs delete-log-group --log-group-name $LOG_GROUP --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || true
done

# Delete IAM Roles
echo "Deleting IAM roles..."
for ROLE in introspect-dpn-eks-cluster-role introspect-dpn-eks-fargate-pod-exec introspect-dpn-node-group-role introspect-dpn-bedrock-access sample-service-bedrock-role introspect-dpn-eks-node-role; do
  for POLICY_ARN in $(aws iam list-attached-role-policies --role-name $ROLE --profile "$AWS_PROFILE" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null); do
    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY_ARN --profile "$AWS_PROFILE" 2>/dev/null || true
  done
  for POLICY_NAME in $(aws iam list-role-policies --role-name $ROLE --profile "$AWS_PROFILE" --query "PolicyNames[]" --output text 2>/dev/null); do
    aws iam delete-role-policy --role-name $ROLE --policy-name $POLICY_NAME --profile "$AWS_PROFILE" 2>/dev/null || true
  done
  aws iam delete-role --role-name $ROLE --profile "$AWS_PROFILE" 2>/dev/null || true
done

# Delete IAM Policies
echo "Deleting IAM policies..."
for POLICY_NAME in bedrock-invoke-policy; do
  POLICY_ARN=$(aws iam list-policies --profile "$AWS_PROFILE" --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text 2>/dev/null)
  if [[ -n "$POLICY_ARN" ]]; then
    aws iam delete-policy --policy-arn $POLICY_ARN --profile "$AWS_PROFILE" 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 3: Destroy Terraform Infrastructure ==="
cd infra/envs/dev

# Remove backend config and .terraform directory
echo "Removing S3 backend configuration..."
cp providers.tf providers.tf.bak 2>/dev/null || true
sed -i.tmp '/backend "s3"/,/^  }/d' providers.tf 2>/dev/null || true
rm -rf .terraform .terraform.lock.hcl

if [[ -n "$TF_STATE_BUCKET" ]]; then
  echo "Downloading state from S3: $TF_STATE_BUCKET"
  aws s3 cp s3://$TF_STATE_BUCKET/instrospect2/dev/terraform.tfstate terraform.tfstate --profile "$AWS_PROFILE" 2>/dev/null || echo "⚠️  Could not download state from S3"
fi

echo "Initializing Terraform with local state..."
terraform init 2>&1 | grep -v "^$" || true

echo "Running terraform destroy..."
terraform destroy -auto-approve 2>&1 || echo "⚠️  No resources to destroy"

# Restore original providers.tf
mv providers.tf.bak providers.tf 2>/dev/null || true
rm -f providers.tf.tmp

cd ../../..
echo "✅ Infrastructure destroy attempted"

echo ""
fi
echo "=== Step 4: Delete S3 State Bucket ==="
if [[ -n "$TF_STATE_BUCKET" ]]; then
  echo "Deleting S3 state bucket: $TF_STATE_BUCKET"
# Use version-aware empty to handle all versions and delete markers
empty_versioned_bucket "$TF_STATE_BUCKET"
aws s3 rb "s3://$TF_STATE_BUCKET" --profile "$AWS_PROFILE" 2>/dev/null \
  && echo "✅ S3 state bucket deleted" \
  || echo "⚠️ Could not delete bucket (may not exist or has pending replication)"
else
  echo "⏭️  No state bucket found, skipping"
fi

echo ""
echo "=== Step 5: Delete All Introspect S3 Buckets ==="
for BUCKET in $(aws s3 ls --profile "$AWS_PROFILE" 2>/dev/null | grep introspect | awk '{print $3}'); do
  echo "Deleting bucket: $BUCKET"
  empty_versioned_bucket "$BUCKET"
  aws s3 rb "s3://$BUCKET" --profile "$AWS_PROFILE" 2>/dev/null || true
done

echo ""
echo "=== Step 6: Final Cleanup ==="
echo "Deleting remaining security groups..."
for SG_ID in $(aws ec2 describe-security-groups --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "SecurityGroups[?contains(GroupName, 'introspect')].GroupId" --output text 2>/dev/null); do
  aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || true
done

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              ✅ Destroy Complete                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "All resources have been destroyed."
echo ""
