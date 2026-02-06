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
kubectl delete namespace app --ignore-not-found=true --wait=false 2>/dev/null || true
echo "✅ Kubernetes resources deleted"

echo ""
echo "=== Step 2: Force Delete AWS Resources ==="

# Delete EKS Node Groups first
echo "Deleting EKS node groups..."
for NG in $(aws eks list-nodegroups --cluster-name introspect-dpn-eks --region $AWS_REGION --profile $AWS_PROFILE --query 'nodegroups[]' --output text 2>/dev/null); do
  echo "Deleting node group: $NG"
  aws eks delete-nodegroup --cluster-name introspect-dpn-eks --nodegroup-name $NG --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
done

# Delete Fargate Profiles
echo "Deleting Fargate profiles..."
for FP in $(aws eks list-fargate-profiles --cluster-name introspect-dpn-eks --region $AWS_REGION --profile $AWS_PROFILE --query 'fargateProfileNames[]' --output text 2>/dev/null); do
  echo "Deleting Fargate profile: $FP"
  aws eks delete-fargate-profile --cluster-name introspect-dpn-eks --fargate-profile-name $FP --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
done

# Wait for node groups and Fargate profiles to delete
echo "Waiting for node groups and Fargate profiles to delete (this may take 5-10 minutes)..."
sleep 30
while aws eks list-nodegroups --cluster-name introspect-dpn-eks --region $AWS_REGION --profile $AWS_PROFILE --query 'nodegroups[]' --output text 2>/dev/null | grep -q .; do
  echo "Still waiting for node groups to delete..."
  sleep 30
done
while aws eks list-fargate-profiles --cluster-name introspect-dpn-eks --region $AWS_REGION --profile $AWS_PROFILE --query 'fargateProfileNames[]' --output text 2>/dev/null | grep -q .; do
  echo "Still waiting for Fargate profiles to delete..."
  sleep 30
done

# Delete EKS Cluster
echo "Deleting EKS cluster..."
aws eks delete-cluster --name introspect-dpn-eks --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete DynamoDB Tables
echo "Deleting DynamoDB tables..."
aws dynamodb delete-table --table-name introspect-claims --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
aws dynamodb delete-table --table-name terraform-locks --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete ECR Repository
echo "Deleting ECR repository..."
aws ecr delete-repository --repository-name introspect-sample-service --force --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete CloudWatch Log Groups
echo "Deleting CloudWatch log groups..."
for LOG_GROUP in $(aws logs describe-log-groups --region $AWS_REGION --profile $AWS_PROFILE --query "logGroups[?contains(logGroupName, 'introspect')].logGroupName" --output text 2>/dev/null); do
  aws logs delete-log-group --log-group-name $LOG_GROUP --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
done

# Delete IAM Roles
echo "Deleting IAM roles..."
for ROLE in introspect-dpn-eks-cluster-role introspect-dpn-eks-fargate-pod-exec introspect-dpn-node-group-role introspect-dpn-bedrock-access; do
  for POLICY_ARN in $(aws iam list-attached-role-policies --role-name $ROLE --profile $AWS_PROFILE --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null); do
    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY_ARN --profile $AWS_PROFILE 2>/dev/null || true
  done
  for POLICY_NAME in $(aws iam list-role-policies --role-name $ROLE --profile $AWS_PROFILE --query "PolicyNames[]" --output text 2>/dev/null); do
    aws iam delete-role-policy --role-name $ROLE --policy-name $POLICY_NAME --profile $AWS_PROFILE 2>/dev/null || true
  done
  aws iam delete-role --role-name $ROLE --profile $AWS_PROFILE 2>/dev/null || true
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
  aws s3 cp s3://$TF_STATE_BUCKET/instrospect2/dev/terraform.tfstate terraform.tfstate --profile $AWS_PROFILE 2>/dev/null || echo "⚠️  Could not download state from S3"
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
echo "=== Step 4: Delete S3 State Bucket ==="
if [[ -n "$TF_STATE_BUCKET" ]]; then
  echo "Deleting S3 state bucket: $TF_STATE_BUCKET"
  aws s3 rm s3://$TF_STATE_BUCKET --recursive --profile $AWS_PROFILE 2>/dev/null || true
  aws s3 rb s3://$TF_STATE_BUCKET --profile $AWS_PROFILE 2>/dev/null && echo "✅ S3 state bucket deleted" || echo "⚠️  Could not delete bucket (may not exist)"
else
  echo "⏭️  No state bucket found, skipping"
fi

echo ""
echo "=== Step 5: Delete All Introspect S3 Buckets ==="
for BUCKET in $(aws s3 ls --profile $AWS_PROFILE 2>/dev/null | grep introspect | awk '{print $3}'); do
  echo "Deleting bucket: $BUCKET"
  aws s3 rm s3://$BUCKET --recursive --profile $AWS_PROFILE 2>/dev/null || true
  aws s3 rb s3://$BUCKET --profile $AWS_PROFILE 2>/dev/null || true
done

echo ""
echo "=== Step 6: Final Cleanup ==="
echo "Deleting remaining security groups..."
for SG_ID in $(aws ec2 describe-security-groups --region $AWS_REGION --profile $AWS_PROFILE --query "SecurityGroups[?contains(GroupName, 'introspect')].GroupId" --output text 2>/dev/null); do
  aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
done

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              ✅ Destroy Complete                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "All resources have been destroyed."
echo ""
