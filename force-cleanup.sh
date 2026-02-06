#!/usr/bin/env bash
set +e

AWS_PROFILE=${AWS_PROFILE:-Deepak}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "🧹 Force cleanup all resources..."
echo ""

# Delete Kubernetes resources
echo "=== Deleting Kubernetes resources ==="
kubectl delete namespace app --ignore-not-found=true --wait=false
kubectl delete namespace default --ignore-not-found=true --wait=false

# Delete EKS cluster
echo "=== Deleting EKS cluster ==="
aws eks delete-cluster --name introspect-dpn-eks --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete Node Groups
echo "=== Deleting Node Groups ==="
aws eks delete-nodegroup --cluster-name introspect-dpn-eks --nodegroup-name introspect-dpn-node-group --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete Fargate Profiles
echo "=== Deleting Fargate Profiles ==="
aws eks delete-fargate-profile --cluster-name introspect-dpn-eks --fargate-profile-name introspect-fargate-profile --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete NLB
echo "=== Deleting Load Balancers ==="
NLB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION --profile $AWS_PROFILE --query "LoadBalancers[?LoadBalancerName=='introspect-nlb'].LoadBalancerArn" --output text 2>/dev/null)
if [[ -n "$NLB_ARN" ]]; then
  aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
fi

# Delete Target Groups
echo "=== Deleting Target Groups ==="
TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION --profile $AWS_PROFILE --query "TargetGroups[?TargetGroupName=='introspect-nlb-tg'].TargetGroupArn" --output text 2>/dev/null)
if [[ -n "$TG_ARN" ]]; then
  aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
fi

# Delete API Gateway
echo "=== Deleting API Gateway ==="
API_ID=$(aws apigatewayv2 get-apis --region $AWS_REGION --profile $AWS_PROFILE --query "Items[?Name=='introspect-claims-api'].ApiId" --output text 2>/dev/null)
if [[ -n "$API_ID" ]]; then
  aws apigatewayv2 delete-api --api-id $API_ID --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
fi

# Delete VPC Links
echo "=== Deleting VPC Links ==="
VPC_LINK_IDS=$(aws apigatewayv2 get-vpc-links --region $AWS_REGION --profile $AWS_PROFILE --query "Items[?contains(Name, 'introspect')].VpcLinkId" --output text 2>/dev/null)
for VPC_LINK_ID in $VPC_LINK_IDS; do
  aws apigatewayv2 delete-vpc-link --vpc-link-id $VPC_LINK_ID --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
done

# Delete DynamoDB Table
echo "=== Deleting DynamoDB Table ==="
aws dynamodb delete-table --table-name introspect-claims --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
aws dynamodb delete-table --table-name terraform-locks --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete S3 Buckets
echo "=== Deleting S3 Buckets ==="
for BUCKET in $(aws s3 ls --profile $AWS_PROFILE 2>/dev/null | grep introspect | awk '{print $3}'); do
  echo "Deleting bucket: $BUCKET"
  aws s3 rm s3://$BUCKET --recursive --profile $AWS_PROFILE 2>/dev/null || true
  aws s3 rb s3://$BUCKET --profile $AWS_PROFILE 2>/dev/null || true
done

# Delete ECR Repository
echo "=== Deleting ECR Repository ==="
aws ecr delete-repository --repository-name introspect-sample-service --force --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true

# Delete CloudWatch Log Groups
echo "=== Deleting CloudWatch Log Groups ==="
for LOG_GROUP in $(aws logs describe-log-groups --region $AWS_REGION --profile $AWS_PROFILE --query "logGroups[?contains(logGroupName, 'introspect')].logGroupName" --output text 2>/dev/null); do
  aws logs delete-log-group --log-group-name $LOG_GROUP --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
done

# Delete IAM Roles
echo "=== Deleting IAM Roles ==="
for ROLE in introspect-dpn-eks-cluster-role introspect-dpn-eks-fargate-pod-exec introspect-dpn-node-group-role introspect-dpn-bedrock-access; do
  # Detach policies first
  for POLICY_ARN in $(aws iam list-attached-role-policies --role-name $ROLE --profile $AWS_PROFILE --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null); do
    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY_ARN --profile $AWS_PROFILE 2>/dev/null || true
  done
  # Delete inline policies
  for POLICY_NAME in $(aws iam list-role-policies --role-name $ROLE --profile $AWS_PROFILE --query "PolicyNames[]" --output text 2>/dev/null); do
    aws iam delete-role-policy --role-name $ROLE --policy-name $POLICY_NAME --profile $AWS_PROFILE 2>/dev/null || true
  done
  # Delete role
  aws iam delete-role --role-name $ROLE --profile $AWS_PROFILE 2>/dev/null || true
done

# Delete Security Groups (after waiting for dependencies)
echo "=== Waiting 30s for dependencies to clear ==="
sleep 30

echo "=== Deleting Security Groups ==="
for SG_ID in $(aws ec2 describe-security-groups --region $AWS_REGION --profile $AWS_PROFILE --query "SecurityGroups[?contains(GroupName, 'introspect')].GroupId" --output text 2>/dev/null); do
  aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION --profile $AWS_PROFILE 2>/dev/null || true
done

echo ""
echo "✅ Force cleanup complete!"
echo "⚠️  Some resources may still be deleting in the background"
echo "Wait 2-3 minutes before redeploying"
