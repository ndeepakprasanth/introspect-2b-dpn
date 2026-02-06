#!/usr/bin/env bash
set -euo pipefail

# deploy-and-test.sh - Complete deployment and testing script
# This script deploys the entire infrastructure and validates functionality

AWS_PROFILE=${AWS_PROFILE:-default}
AWS_REGION=${AWS_REGION:-us-east-1}
TF_STATE_BUCKET=${TF_STATE_BUCKET:-}
TF_STATE_KEY=${TF_STATE_KEY:-instrospect2/dev/terraform.tfstate}
DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-locks}
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-introspect-dpn-eks}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Introspect-2B Complete Deployment ==="
echo "AWS_PROFILE: $AWS_PROFILE"
echo "AWS_REGION: $AWS_REGION"
echo "EKS_CLUSTER: $EKS_CLUSTER_NAME"
echo ""

# Step 1: Bootstrap infrastructure
echo "Step 1: Bootstrapping infrastructure..."
if [[ -z "$TF_STATE_BUCKET" ]]; then
  read -rp "Enter Terraform state S3 bucket name: " TF_STATE_BUCKET
fi

export TF_STATE_BUCKET TF_STATE_KEY AWS_REGION DYNAMODB_TABLE
"$REPO_ROOT/bootstrap-infra.sh"

# Step 2: Get outputs
echo ""
echo "Step 2: Retrieving infrastructure outputs..."
cd "$REPO_ROOT/infra/envs/dev"
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
S3_BUCKET=$(terraform output -raw s3_notes_bucket 2>/dev/null || echo "")
DYNAMODB_TABLE_NAME=$(terraform output -raw dynamodb_table 2>/dev/null || echo "")
BEDROCK_ROLE_ARN=$(terraform output -raw bedrock_role_arn 2>/dev/null || echo "")
cd "$REPO_ROOT"

echo "API Endpoint: $API_ENDPOINT"
echo "ECR Repository: $ECR_REPO"
echo "S3 Bucket: $S3_BUCKET"
echo "DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo "Bedrock Role ARN: $BEDROCK_ROLE_ARN"

# Step 3: Upload mock data to S3
echo ""
echo "Step 3: Uploading mock data to S3..."
if [[ -n "$S3_BUCKET" ]]; then
  aws s3 cp "$REPO_ROOT/mocks/claims.json" "s3://$S3_BUCKET/claims.json" --profile "$AWS_PROFILE"
  aws s3 cp "$REPO_ROOT/mocks/notes.json" "s3://$S3_BUCKET/notes.json" --profile "$AWS_PROFILE"
  echo "Mock data uploaded successfully"
fi

# Step 4: Build and push image
echo ""
echo "Step 4: Building and pushing Docker image..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$AWS_PROFILE")
IMAGE_TAG=${IMAGE_TAG:-latest}
IMAGE_FULL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/introspect-sample-service:$IMAGE_TAG"

cd "$REPO_ROOT/app/services/sample-service"
docker build -t introspect-sample-service:$IMAGE_TAG .
docker tag introspect-sample-service:$IMAGE_TAG "$IMAGE_FULL"

aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" | \
  docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

docker push "$IMAGE_FULL"
echo "Image pushed: $IMAGE_FULL"
cd "$REPO_ROOT"

# Step 5: Deploy to EKS
echo ""
echo "Step 5: Deploying to EKS..."
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE"

helm upgrade --install sample-service "$REPO_ROOT/app/services/sample-service" \
  -n default --create-namespace \
  --set image.repository="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/introspect-sample-service" \
  --set image.tag="$IMAGE_TAG" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$BEDROCK_ROLE_ARN" \
  --wait --timeout 300s

kubectl rollout status deployment/sample-service -n default --timeout=300s

# Step 6: Test endpoints
echo ""
echo "Step 6: Testing API endpoints..."
echo "Waiting for service to be ready..."
sleep 10

# Get service endpoint
SERVICE_URL=$(kubectl get svc sample-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [[ -z "$SERVICE_URL" ]]; then
  # If LoadBalancer not available, use port-forward
  echo "Using port-forward for testing..."
  kubectl port-forward svc/sample-service 8080:8080 -n default &
  PF_PID=$!
  sleep 5
  SERVICE_URL="localhost:8080"
fi

echo ""
echo "Testing GET /claims/1001..."
curl -s "http://$SERVICE_URL/claims/1001" | jq . || echo "Test failed"

echo ""
echo "Testing POST /claims/1001/summarize..."
curl -s -X POST "http://$SERVICE_URL/claims/1001/summarize" | jq . || echo "Test failed"

if [[ -n "${PF_PID:-}" ]]; then
  kill $PF_PID 2>/dev/null || true
fi

# Step 7: Display summary
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Resources:"
echo "  API Gateway: $API_ENDPOINT"
echo "  ECR Repository: $ECR_REPO"
echo "  S3 Bucket: $S3_BUCKET"
echo "  DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo ""
echo "Next steps:"
echo "  1. View Inspector findings: AWS Console > Inspector > Container image scanning"
echo "  2. View Security Hub: AWS Console > Security Hub > Findings"
echo "  3. View CloudWatch Logs: AWS Console > CloudWatch > Log groups"
echo "  4. Test API Gateway: curl $API_ENDPOINT/claims/1001"
echo ""
echo "To view pods: kubectl get pods -n default"
echo "To view logs: kubectl logs -f deployment/sample-service -n default"
