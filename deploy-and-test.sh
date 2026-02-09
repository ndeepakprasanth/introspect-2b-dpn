#!/usr/bin/env bash
set -euo pipefail

# deploy-and-test.sh - Complete deployment and testing script
# This script deploys the entire infrastructure and validates functionality

AWS_PROFILE=${AWS_PROFILE:-Deepak}
AWS_REGION=${AWS_REGION:-us-east-1}
TF_STATE_BUCKET=${TF_STATE_BUCKET:-}
TF_STATE_KEY=${TF_STATE_KEY:-instrospect2/dev/terraform.tfstate}
DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-locks}
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-introspect-dpn-eks}

# ---- Stable Terraform state bucket autodetect/derive ----
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --profile "$AWS_PROFILE")"

# Derive a stable default bucket name
DEFAULT_TF_STATE_BUCKET="introspect-tf-state-${AWS_ACCOUNT_ID}-${AWS_REGION}"

# If user didn't pass TF_STATE_BUCKET, try to find an existing state bucket; otherwise fall back to the stable default.
if [[ -z "${TF_STATE_BUCKET:-}" ]]; then
  EXISTING_STATE_BUCKET="$(aws s3 ls --profile "$AWS_PROFILE" 2>/dev/null | awk '/introspect-tf-state/{print $3; exit}')"
  TF_STATE_BUCKET="${EXISTING_STATE_BUCKET:-$DEFAULT_TF_STATE_BUCKET}"
fi

export TF_STATE_BUCKET

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Introspect-2B Complete Deployment                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "AWS_PROFILE: $AWS_PROFILE"
echo "AWS_REGION: $AWS_REGION"
echo "EKS_CLUSTER: $EKS_CLUSTER_NAME"
echo ""

# Pre-flight checks
echo "=== Pre-flight Checks ==="
ERRORS=0
echo "Checking for existing resources..."
if [[ "${ALLOW_EXISTING:-true}" == "true" ]]; then echo "Pre-flight: ALLOW_EXISTING=true → skipping existing resource checks"; else
ERRORS=0
fi
# Check for existing EKS cluster
if aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    echo "❌ EKS cluster '$EKS_CLUSTER_NAME' already exists"
    ERRORS=$((ERRORS+1))
fi

# Check for existing DynamoDB table
if aws dynamodb describe-table --table-name introspect-claims --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
  echo "❌ DynamoDB table 'introspect-claims' already exists"
  ERRORS=$((ERRORS + 1))
fi

# Check for existing ECR repository
if aws ecr describe-repositories --repository-names introspect-sample-service --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
  echo "❌ ECR repository 'introspect-sample-service' already exists"
  ERRORS=$((ERRORS + 1))
fi

# Check for existing IAM roles
for ROLE in introspect-dpn-eks-cluster-role introspect-dpn-eks-fargate-pod-exec introspect-dpn-node-group-role; do
  if aws iam get-role --role-name "$ROLE" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    echo "❌ IAM role '$ROLE' already exists"
    ERRORS=$((ERRORS + 1))
    break
  fi
done

# Check for existing NLB
if aws elbv2 describe-load-balancers --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "LoadBalancers[?LoadBalancerName=='introspect-nlb']" --output text 2>/dev/null | grep -q .; then
  echo "❌ Load balancer 'introspect-nlb' already exists"
  ERRORS=$((ERRORS + 1))
fi

# correct logic we will apply after I see the line numbers
if [[ $ERRORS -gt 0 && "${ALLOW_EXISTING:-}" != "true" ]]; then
  if [[ "${ALLOW_EXISTING:-}" == "1" ]]; then
    echo ""
    echo "ALLOW_EXISTING=1 set → continuing despite existing resources."
    echo ""
  else
    echo ""
    echo "⚠️ Found $ERRORS existing resource(s) that will conflict with deployment."
    echo ""
    echo "Run './destroy.sh' to clean up existing resources, then try again."
    echo ""
    exit 1
  fi
else
  echo "✅ No conflicting resources found"
  echo ""
fi

# Reset the error counter before the tools check
ERRORS=0

# Check required tools
echo "=== Checking Required Tools ==="
for CMD in aws terraform docker kubectl helm jq; do
  if ! command -v $CMD &>/dev/null; then
    echo "❌ $CMD is not installed"
    ERRORS=$((ERRORS + 1))
  else
    echo "✅ $CMD"
  fi
done

if [[ $ERRORS -gt 0 && "${ALLOW_EXISTING:-}" != "true" ]]; then
  echo ""
  echo "❌ Missing required tools. Please install them and try again."
  exit 1
fi
echo ""

# Step 1: Bootstrap infrastructure
echo "Step 1: Bootstrapping infrastructure..."
if [[ -z "$TF_STATE_BUCKET" ]]; then
  read -rp "Enter Terraform state S3 bucket name: " TF_STATE_BUCKET
fi

export TF_STATE_BUCKET TF_STATE_KEY AWS_REGION DYNAMODB_TABLE AWS_PROFILE
"$REPO_ROOT/bootstrap-infra.sh"

# NEW: Initialize and apply Terraform so infra exists before reading outputs
cd "$REPO_ROOT/infra/envs/dev"
cd "$REPO_ROOT"

# Step 2: Get outputs
# Step 2: Retrieving infrastructure outputs...
echo ""
echo "Step 2: Retrieving infrastructure outputs..."
cd "$REPO_ROOT/infra/envs/dev"

# Non-interactive, idempotent init (only if not already initialized)
if [ ! -d .terraform ]; then
  terraform init -input=false
fi

# Make sure infra exists before reading outputs
terraform apply -auto-approve

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

# Fallbacks when Terraform outputs are empty (ALLOW_EXISTING path)
if [[ -z "$ECR_REPO" ]]; then
  ECR_REPO=$(aws ecr describe-repositories \
    --repository-names introspect-sample-service \
    --region "$AWS_REGION" --profile "$AWS_PROFILE" \
    --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo "")
fi

if [[ -z "$S3_BUCKET" ]]; then
  # Pick first bucket that matches the pattern used by Terraform
  S3_BUCKET=$(aws s3 ls --profile "$AWS_PROFILE" 2>/dev/null \
    | awk '/introspect-sample-service-notes-/{print $3; exit}')
fi

if [[ -z "$DYNAMODB_TABLE_NAME" ]]; then
  DYNAMODB_TABLE_NAME="introspect-claims"
fi

if [[ -z "$BEDROCK_ROLE_ARN" ]]; then
  BEDROCK_ROLE_ARN=$(aws iam get-role \
    --role-name sample-service-bedrock-role \
    --profile "$AWS_PROFILE" \
    --query 'Role.Arn' --output text 2>/dev/null || echo "")
fi

if [[ -z "$API_ENDPOINT" ]]; then
  API_ID=$(aws apigatewayv2 get-apis \
    --region "$AWS_REGION" --profile "$AWS_PROFILE" \
    --query "Items[?Name=='introspect-claims-api'].ApiId" \
    --output text 2>/dev/null || echo "")
  if [[ -n "$API_ID" ]]; then
    API_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com"
  fi
fi
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

# Login to ECR (must be before pushing)
aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Ensure a buildx builder exists (idempotent; ignore error if it already exists)
docker buildx create --name multi --driver docker-container --use >/dev/null 2>&1 || true

# Build **amd64** image and push straight to ECR
docker buildx build --platform linux/amd64 \
  -t "$IMAGE_FULL" \
  --push .

echo "Image pushed (amd64): $IMAGE_FULL"

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

kubectl rollout status deployment/sample-service-sample-service -n default --timeout=300s

# Step 5.5: Mounting mocks and setting MOCKS_PATH (idempotent)
echo ""
echo "Step 5.5: Mounting mocks and setting MOCKS_PATH..."

# Create or update a ConfigMap from repo-level mocks
kubectl create configmap sample-mocks \
  --from-file=claims.json="$REPO_ROOT/mocks/claims.json" \
  --from-file=notes.json="$REPO_ROOT/mocks/notes.json" \
  -n default \
  --dry-run=client -o yaml | kubectl apply -f -

# Ensure env var is set on the Deployment (idempotent)
kubectl set env deployment/sample-service-sample-service -n default MOCKS_PATH=/app/mocks

# Ensure a 'mocks' volume exists (merge-patch; safe if it already exists)
kubectl patch deployment sample-service-sample-service -n default --type='merge' -p '{
  "spec": { "template": { "spec": { "volumes": [
    { "name":"mocks", "configMap": { "name":"sample-mocks" } }
  ]}}}
}' || true

# Ensure the volume is mounted into the first container (add or append)
kubectl patch deployment sample-service-sample-service -n default --type='json' -p '[
  { "op":"add", "path":"/spec/template/spec/containers/0/volumeMounts",
    "value":[{ "name":"mocks","mountPath":"/app/mocks","readOnly":true }] }
]' || kubectl patch deployment sample-service-sample-service -n default --type='json' -p '[
  { "op":"add", "path":"/spec/template/spec/containers/0/volumeMounts/-",
    "value":{ "name":"mocks","mountPath":"/app/mocks","readOnly":true } }
]'

# Wait for the rollout to complete after patches
kubectl rollout status deployment/sample-service-sample-service -n default --timeout=300s

# Step 6: Test API endpoints
echo ""
echo "Step 6: Testing API endpoints..."
echo "Waiting for service to be ready..."
sleep 10

# Get service endpoint
SERVICE_URL=$(kubectl get svc sample-service-sample-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [[ -z "$SERVICE_URL" ]]; then
  # If LoadBalancer not available, use port-forward
  echo "Using port-forward for testing..."
  kubectl port-forward svc/sample-service-sample-service 8080:8080 -n default &
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
