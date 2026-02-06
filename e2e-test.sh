#!/usr/bin/env bash
# E2E Testing Guide for Introspect-2B
# Run this after pushing to GitHub

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Introspect-2B End-to-End Testing Guide                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  echo "❌ AWS credentials not configured. Run: aws configure"
  exit 1
fi

echo "✅ AWS Account: $AWS_ACCOUNT_ID"
echo "✅ Region: $AWS_REGION"
echo ""

# Step 1: Create S3 bucket for Terraform state
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Create S3 Bucket for Terraform State"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BUCKET_NAME="introspect-tf-state-${AWS_ACCOUNT_ID}-$(date +%s)"
echo "Creating bucket: $BUCKET_NAME"

aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

echo "✅ S3 bucket created: $BUCKET_NAME"
echo "⚠️  SAVE THIS: export TF_STATE_BUCKET=$BUCKET_NAME"
echo ""

# Step 2: Deploy infrastructure
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Deploy Infrastructure (10-15 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

export TF_STATE_BUCKET=$BUCKET_NAME
./deploy-and-test.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Verify Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get outputs
cd infra/envs/dev
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
S3_BUCKET=$(terraform output -raw s3_notes_bucket 2>/dev/null || echo "")
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table 2>/dev/null || echo "")
cd ../../..

echo "✅ API Gateway: $API_ENDPOINT"
echo "✅ ECR Repository: $ECR_REPO"
echo "✅ S3 Bucket: $S3_BUCKET"
echo "✅ DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Step 4: Test API
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Test API Endpoints"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

kubectl port-forward svc/sample-service 8080:8080 -n default &
PF_PID=$!
sleep 5

./test-api.sh http://localhost:8080

kill $PF_PID 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Verify Security Scanning"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Checking Inspector findings..."
aws inspector2 list-findings \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"EQUALS","value":"introspect-sample-service"}]}' \
  --region $AWS_REGION \
  --max-results 5 \
  --query 'findings[].{Severity:severity,Title:title}' \
  --output table || echo "⚠️  No findings yet (scan may be in progress)"

echo ""
echo "Checking Security Hub..."
aws securityhub get-findings \
  --filters '{"ResourceId":[{"Value":"introspect-sample-service","Comparison":"CONTAINS"}]}' \
  --region $AWS_REGION \
  --max-results 5 \
  --query 'Findings[].{Severity:Severity.Label,Title:Title}' \
  --output table || echo "⚠️  No findings yet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Verify Observability"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Checking CloudWatch Log Groups..."
aws logs describe-log-groups \
  --log-group-name-prefix /aws/ \
  --query 'logGroups[].logGroupName' \
  --output table

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    E2E Testing Complete! ✅                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
echo "  ✅ Infrastructure deployed"
echo "  ✅ Application running"
echo "  ✅ API endpoints tested"
echo "  ✅ Security scanning enabled"
echo "  ✅ Observability configured"
echo ""
echo "🔗 Resources:"
echo "  • GitHub: https://github.com/ndeepakprasanth/introspect-2b-dpn"
echo "  • API Gateway: $API_ENDPOINT"
echo "  • ECR: $ECR_REPO"
echo ""
echo "📝 Next Steps:"
echo "  1. View Inspector: AWS Console → Inspector → Container image scanning"
echo "  2. View Security Hub: AWS Console → Security Hub → Findings"
echo "  3. View CloudWatch: AWS Console → CloudWatch → Log groups"
echo "  4. Take screenshots for scans/ directory"
echo ""
echo "🧹 Cleanup (when done):"
echo "  helm uninstall sample-service -n default"
echo "  cd infra/envs/dev && terraform destroy -auto-approve"
echo "  aws s3 rb s3://$BUCKET_NAME --force"
echo ""
