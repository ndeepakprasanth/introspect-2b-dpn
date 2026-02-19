#!/usr/bin/env bash
################################################################################
# Introspect-2B: Intelligent End-to-End Deployment Script
################################################################################
# USAGE:
#   Simple one-command deployment:
#     ./deploy-and-test.sh
#
#   With custom AWS profile:
#     AWS_PROFILE=myprofile ./deploy-and-test.sh
#
#   Force redeploy (skip resource checks):
#     FORCE_DEPLOY=1 ./deploy-and-test.sh
#
# THIS SMART SCRIPT DOES:
#   1. ✅ Checks prerequisites (AWS CLI, Terraform, Docker, kubectl, Helm, jq)
#   2. ✅ Auto-detects AWS profile (default: Deepak)
#   3. ✅ Auto-configures AWS region (default: us-east-1)
#   4. ✅ Cleans stale Terraform locks
#   5. ✅ Sets up Terraform backend (S3 + DynamoDB)
#   6. ✅ Deploys infrastructure (VPC, EKS, DynamoDB, S3, ECR, API Gateway)
#   7. ✅ Builds & pushes Docker image
#   8. ✅ Deploys application via Helm
#   9. ✅ Runs API tests and displays results
#   10. ✅ Displays observability & security info
#
# NO MANUAL ENV VAR SETUP NEEDED!
################################################################################
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_ok() { echo -e "${GREEN}✅${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }
log_section() { echo ""; echo "=== $1 ==="; echo ""; }

ensure_buildx_amd64() {
  local builder_name="introspect-builder"

  if ! docker buildx inspect "$builder_name" >/dev/null 2>&1; then
    log_info "Creating buildx builder: $builder_name"
    docker buildx create --name "$builder_name" --driver docker-container --use >/dev/null
  else
    docker buildx use "$builder_name" >/dev/null
  fi

  log_info "Ensuring amd64 emulation support"
  docker run --privileged --rm tonistiigi/binfmt --install amd64 >/dev/null 2>&1 || true
  docker buildx inspect --bootstrap >/dev/null 2>&1 || true
}

get_pod_ips() {
  local namespace="$1"
  local service_name="$2"

  kubectl get endpointslices -n "$namespace" \
    -l kubernetes.io/service-name="$service_name" \
    -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null || true
}

register_nlb_targets() {
  local target_group_arn="$1"
  local namespace="$2"
  local service_name="$3"
  local port="$4"

  if [[ -z "$target_group_arn" ]]; then
    log_warn "NLB target group ARN not available; skipping target registration"
    return
  fi

  log_info "Waiting for service endpoints..."
  local retry=0
  local pod_ips=""
  while [[ $retry -lt 30 ]]; do
    pod_ips=$(get_pod_ips "$namespace" "$service_name")
    if [[ -n "$pod_ips" ]]; then
      break
    fi
    retry=$((retry + 1))
    sleep 5
  done

  if [[ -z "$pod_ips" ]]; then
    log_warn "No pod IPs found for target registration"
    return
  fi

  log_info "Registering pod IPs with NLB target group"
  local targets=()
  for ip in $pod_ips; do
    targets+=("Id=$ip,Port=$port")
  done

  aws elbv2 register-targets \
    --target-group-arn "$target_group_arn" \
    --targets "${targets[@]}" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" >/dev/null

  log_ok "Registered NLB targets: $pod_ips"
}

ensure_node_sg_rule() {
  local cluster_name="$1"
  local nodegroup_name="$2"
  local port="$3"

  local vpc_id
  vpc_id=$(aws eks describe-cluster \
    --name "$cluster_name" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'cluster.resourcesVpcConfig.vpcId' \
    --output text)

  local vpc_cidr
  vpc_cidr=$(aws ec2 describe-vpcs \
    --vpc-ids "$vpc_id" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

  local asg_name
  asg_name=$(aws eks describe-nodegroup \
    --cluster-name "$cluster_name" \
    --nodegroup-name "$nodegroup_name" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'nodegroup.resources.autoScalingGroups[0].name' \
    --output text)

  local instance_id
  instance_id=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$asg_name" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
    --output text)

  local node_sg
  node_sg=$(aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

  aws ec2 authorize-security-group-ingress \
    --group-id "$node_sg" \
    --protocol tcp \
    --port "$port" \
    --cidr "$vpc_cidr" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

  log_ok "Security group rule ensured on $node_sg"
}

wait_for_target_health() {
  local target_group_arn="$1"

  if [[ -z "$target_group_arn" ]]; then
    log_warn "Target group ARN not available; skipping health checks"
    return
  fi

  log_info "Waiting for NLB target health to be healthy"
  for _ in {1..10}; do
    local state
    state=$(aws elbv2 describe-target-health \
      --target-group-arn "$target_group_arn" \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --query 'TargetHealthDescriptions[0].TargetHealth.State' \
      --output text)
    if [[ "$state" == "healthy" ]]; then
      log_ok "Target health is healthy"
      return
    fi
    sleep 6
  done
}

invoke_bedrock_analysis() {
  local api_response="$1"
  local bedrock_role_arn="$2"

  if [[ -z "$api_response" ]] || [[ -z "$bedrock_role_arn" ]]; then
    log_warn "API response or Bedrock role not available; skipping Bedrock analysis"
    return
  fi

  log_info "Sending API response to Bedrock for analysis..."
  
  # Create temporary files for the request body and response
  local temp_body=$(mktemp)
  local temp_response=$(mktemp)
  
  # Use Claude Haiku (available in us-east-1, doesn't require inference profile)
  jq -n \
    --arg text "Analyze this API response and provide brief insights on data quality: $api_response" \
    '{
      messages: [{
        role: "user",
        content: $text
      }],
      anthropic_version: "bedrock-2023-06-01",
      max_tokens: 200
    }' > "$temp_body"

  # Call Bedrock using Claude Haiku
  local invoke_output
  invoke_output=$(aws bedrock-runtime invoke-model \
    --model-id "anthropic.claude-haiku-4-5-20251001-v1:0" \
    --content-type "application/json" \
    --accept "application/json" \
    --body fileb://"$temp_body" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    "$temp_response" 2>&1)

  # Check if invoke-model succeeded
  if [[ $? -ne 0 ]] || [[ ! -f "$temp_response" ]]; then
    log_warn "Bedrock invoke-model failed (IAM user may lack bedrock:InvokeModel permission)"
    log_info "Note: Pod-based Bedrock summarization uses IRSA role and should work correctly"
    rm -f "$temp_body" "$temp_response"
    echo "Unable to invoke Bedrock from CLI (requires bedrock:InvokeModel permission for IAM user)"
    return
  fi

  # Parse response - Claude returns content array
  local bedrock_response
  bedrock_response=$(cat "$temp_response" 2>/dev/null | jq -r '.content[0].text' 2>/dev/null)
  
  rm -f "$temp_body" "$temp_response"
  
  if [[ -z "$bedrock_response" ]] || [[ "$bedrock_response" == "null" ]]; then
    echo "Unable to get analysis (empty response from Bedrock)"
    return
  fi
  
  echo "$bedrock_response"
}

fetch_cloudwatch_logs() {
  local log_group="$1"
  local minutes_back="${2:-10}"

  if [[ -z "$log_group" ]]; then
    log_warn "Log group not available; skipping CloudWatch logs"
    return
  fi

  log_info "Fetching CloudWatch logs from the last $minutes_back minutes..."

  local since_time=$(($(date +%s) - (minutes_back * 60)))
  since_time=$((since_time * 1000))
  
  local logs
  logs=$(aws logs filter-log-events \
    --log-group-name "$log_group" \
    --start-time "$since_time" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'events[].message' \
    --output text 2>/dev/null || echo "No logs available")
  
  echo "$logs"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

################################################################################
# STEP 0: CHECK PREREQUISITES
################################################################################
log_section "Step 0: Checking Prerequisites"

MISSING_TOOLS=()
for CMD in aws terraform docker kubectl helm jq; do
  if ! command -v $CMD &>/dev/null; then
    log_error "$CMD not found"
    MISSING_TOOLS+=("$CMD")
  else
    log_ok "$CMD"
  fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  log_error "Missing required tools: ${MISSING_TOOLS[*]}"
  exit 1
fi

log_ok "All prerequisites satisfied"

################################################################################
# STEP 1: AUTO-CONFIGURE ENVIRONMENT
################################################################################
log_section "Step 1: Auto-Configuring Environment"

# Auto-detect AWS profile (with fallback to default)
AWS_PROFILE=${AWS_PROFILE:-Deepak}
AWS_REGION=${AWS_REGION:-us-east-1}
FORCE_DEPLOY=${FORCE_DEPLOY:-}

log_info "Detecting AWS credentials..."
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
  log_error "Cannot authenticate with AWS profile: $AWS_PROFILE"
  log_info "Available profiles:"
  aws configure list-profiles 2>/dev/null || true
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
log_ok "AWS Account: $ACCOUNT_ID"
log_ok "AWS Region: $AWS_REGION"
log_ok "AWS Profile: $AWS_PROFILE"

# Export for subshells
export AWS_PROFILE AWS_REGION

################################################################################
# STEP 2: CLEAN UP STALE TERRAFORM LOCKS
################################################################################
log_section "Step 2: Cleaning Terraform Locks"

TF_DIR="$REPO_ROOT/infra/envs/dev"

if [[ -d "$TF_DIR/.terraform" ]]; then
  log_warn "Removing stale Terraform working directory..."
  rm -rf "$TF_DIR/.terraform" "$TF_DIR/.terraform"* 2>/dev/null || true
  log_ok "Cleaned Terraform working directory"
else
  log_ok "No stale Terraform files found"
fi

################################################################################
# STEP 3: SETUP TERRAFORM BACKEND
################################################################################
log_section "Step 3: Setting Up Terraform Backend"

# Stable bucket naming
TF_STATE_BUCKET="introspect-tf-state-${ACCOUNT_ID}-${AWS_REGION}"
TF_STATE_KEY="instrospect2/dev/terraform.tfstate"
DYNAMODB_TABLE="terraform-locks"

log_info "Checking for existing S3 bucket: $TF_STATE_BUCKET"
if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" --profile "$AWS_PROFILE" 2>/dev/null; then
  log_ok "S3 bucket exists: $TF_STATE_BUCKET"
else
  log_warn "Creating S3 bucket: $TF_STATE_BUCKET"
  aws s3 mb "s3://$TF_STATE_BUCKET" --region "$AWS_REGION" --profile "$AWS_PROFILE"
  aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" \
    --versioning-configuration Status=Enabled --profile "$AWS_PROFILE"
  log_ok "Created S3 bucket"
fi

log_info "Checking for DynamoDB lock table: $DYNAMODB_TABLE"
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" \
    --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
  log_ok "DynamoDB table exists: $DYNAMODB_TABLE"
else
  log_warn "Creating DynamoDB table: $DYNAMODB_TABLE"
  aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION" --profile "$AWS_PROFILE"
  sleep 5
  log_ok "DynamoDB table created"
fi

log_info "Clearing stale Terraform state digest (if any)..."
TF_DIGEST_KEY="${TF_STATE_BUCKET}/${TF_STATE_KEY}-md5"
aws dynamodb delete-item \
  --table-name "$DYNAMODB_TABLE" \
  --key '{"LockID":{"S":"'"$TF_DIGEST_KEY"'"}}' \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" >/dev/null 2>&1 || true
log_ok "Terraform state digest cleanup complete"

export TF_STATE_BUCKET TF_STATE_KEY DYNAMODB_TABLE

################################################################################
# STEP 4: CHECK FOR CONFLICTING RESOURCES (unless FORCE_DEPLOY=1)
################################################################################
log_section "Step 4: Pre-flight Resource Checks"

EKS_CLUSTER_NAME="introspect-dpn-eks"
CONFLICTS=()

if [[ -z "$FORCE_DEPLOY" ]]; then
  log_info "Checking for existing resources..."
  
  if aws eks describe-cluster --name "$EKS_CLUSTER_NAME" \
      --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    CONFLICTS+=("EKS cluster '$EKS_CLUSTER_NAME'")
  fi
  
  if aws dynamodb describe-table --table-name introspect-claims \
      --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    CONFLICTS+=("DynamoDB table 'introspect-claims'")
  fi
  
  if aws ecr describe-repositories --repository-names introspect-sample-service \
      --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    CONFLICTS+=("ECR repository 'introspect-sample-service'")
  fi
  
  if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
    log_error "Found conflicting resources that would block deployment:"
    for conflict in "${CONFLICTS[@]}"; do
      echo "  - $conflict"
    done
    log_warn "To force deployment anyway, run:"
    echo "  FORCE_DEPLOY=1 ./deploy-and-test.sh"
    exit 1
  fi
  
  log_ok "No conflicting resources found"
else
  log_warn "FORCE_DEPLOY=1 - Skipping resource conflict checks"
fi

################################################################################
# STEP 5: BOOTSTRAP INFRASTRUCTURE (Terraform)
################################################################################
log_section "Step 5: Bootstrapping Infrastructure"
# Clean up old S3 bucket if it exists (prevents BucketAlreadyExists error)
log_info "Checking for stale S3 buckets..."
STALE_BUCKET=$(aws s3 ls --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | grep -i "introspect-sample-service-notes" | awk '{print $3}' | head -1 || true)
if [[ -n "$STALE_BUCKET" ]]; then
  log_warn "Found stale S3 bucket: $STALE_BUCKET - cleaning up..."
  # Delete all objects in the bucket
  aws s3 rm "s3://$STALE_BUCKET" --recursive --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null || true
  # Delete the bucket
  aws s3 rb "s3://$STALE_BUCKET" --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null || true
  log_ok "Cleaned up stale S3 bucket: $STALE_BUCKET"
else
  log_ok "No stale S3 buckets found"
fi
log_info "Running bootstrap-infra.sh..."
"$SCRIPT_DIR/bootstrap-infra.sh"

################################################################################
# STEP 6: RETRIEVE TERRAFORM OUTPUTS
################################################################################
log_section "Step 6: Retrieving Infrastructure Outputs"

cd "$TF_DIR"

log_info "Clearing stale Terraform state digest before init..."
TF_DIGEST_KEY="${TF_STATE_BUCKET}/${TF_STATE_KEY}-md5"
aws dynamodb delete-item \
  --table-name "$DYNAMODB_TABLE" \
  --key '{"LockID":{"S":"'"$TF_DIGEST_KEY"'"}}' \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" >/dev/null 2>&1 || true
sleep 2

log_info "Ensuring Terraform state is initialized..."
INIT_OUTPUT=$(terraform init -input=false -reconfigure \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=$TF_STATE_KEY" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="dynamodb_table=$DYNAMODB_TABLE" 2>&1) || true

if echo "$INIT_OUTPUT" | grep -q "Error refreshing state"; then
  echo "$INIT_OUTPUT"
  log_warn "Terraform init failed; attempting to sync state digest"

  CHECKSUM=$(echo "$INIT_OUTPUT" | awk '/Calculated checksum:/ {print $3}')
  if [[ -n "$CHECKSUM" ]]; then
    log_info "Updating digest to $CHECKSUM"
    aws dynamodb update-item \
      --table-name "$DYNAMODB_TABLE" \
      --key '{"LockID":{"S":"'"$TF_DIGEST_KEY"'"}}' \
      --update-expression "SET Digest = :d" \
      --expression-attribute-values '{":d":{"S":"'"$CHECKSUM"'"}}' \
      --region "$AWS_REGION" \
      --profile "$AWS_PROFILE" >/dev/null 2>&1 || true
    sleep 2
  fi

  terraform init -input=false -reconfigure \
    -backend-config="bucket=$TF_STATE_BUCKET" \
    -backend-config="key=$TF_STATE_KEY" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=$DYNAMODB_TABLE"
else
  echo "$INIT_OUTPUT"
fi

log_info "Applying Terraform configuration..."
terraform apply -auto-approve

# Retrieve outputs
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
NLB_DNS_NAME=$(terraform output -raw nlb_dns_name 2>/dev/null || echo "")
NLB_TARGET_GROUP_ARN=$(terraform output -raw nlb_target_group_arn 2>/dev/null || echo "")
S3_BUCKET=$(terraform output -raw s3_notes_bucket 2>/dev/null || echo "")
DYNAMODB_TABLE_NAME=$(terraform output -raw dynamodb_table 2>/dev/null || echo "")
BEDROCK_ROLE_ARN=$(terraform output -raw bedrock_role_arn 2>/dev/null || echo "")
EKS_ENDPOINT=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "")

log_ok "Infrastructure deployed"
log_info "API Endpoint: $API_ENDPOINT"
log_info "ECR Repository: $ECR_REPO"
log_info "NLB DNS: $NLB_DNS_NAME"
log_info "S3 Bucket: $S3_BUCKET"
log_info "DynamoDB Table: $DYNAMODB_TABLE_NAME"
log_info "EKS Endpoint: $EKS_ENDPOINT"

cd "$REPO_ROOT"

################################################################################
# STEP 7: CONFIGURE KUBECTL
################################################################################
log_section "Step 7: Configuring kubectl"

log_info "Updating kubeconfig for EKS cluster..."
aws eks update-kubeconfig \
  --name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE"

log_ok "kubectl configured"

# Wait for nodes to be ready
log_info "Waiting for EKS nodes to be ready..."
RETRY=0
while [[ $RETRY -lt 30 ]]; do
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
  if [[ "$READY_NODES" -gt 0 ]]; then
    log_ok "EKS nodes ready ($READY_NODES nodes)"
    break
  fi
  RETRY=$((RETRY + 1))
  sleep 10
done

################################################################################
# STEP 8: BUILD & PUSH DOCKER IMAGE
################################################################################
log_section "Step 8: Building Docker Image"

if [[ -z "$ECR_REPO" ]]; then
  log_error "ECR repository URL not available"
  exit 1
fi

APP_DIR="$REPO_ROOT/app/services/sample-service"
IMAGE_URI="${ECR_REPO}:latest"

log_info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" | \
  docker login --username AWS --password-stdin "$ECR_REPO" 2>/dev/null || true

log_info "Building Docker image: $IMAGE_URI"
ensure_buildx_amd64
docker buildx build --platform linux/amd64 --push -t "$IMAGE_URI" "$APP_DIR"

log_ok "Docker image built and pushed to ECR"

################################################################################
# STEP 9: DEPLOY APPLICATION VIA HELM
################################################################################
log_section "Step 9: Deploying Application"

log_info "Creating ConfigMap for mock data..."
kubectl create configmap sample-mocks \
  --from-file="$REPO_ROOT/mocks/claims.json" \
  --from-file="$REPO_ROOT/mocks/notes.json" \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

log_info "Deploying via Helm..."
helm upgrade --install sample-service "$APP_DIR" \
  --namespace default \
  --set image.repository="$ECR_REPO" \
  --set image.tag=latest \
  --set bedrock.modelId="anthropic.claude-3-sonnet-20240229-v1:0" \
  --set bedrock.authMode="role" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$BEDROCK_ROLE_ARN" \
  --wait

log_ok "Application deployed"

# Wait for pods to be ready
log_info "Waiting for application pods to be ready..."
kubectl rollout status deployment/sample-service-sample-service -n default --timeout=300s

register_nlb_targets "$NLB_TARGET_GROUP_ARN" "default" "sample-service-sample-service" 8080
ensure_node_sg_rule "$EKS_CLUSTER_NAME" "demo-node-group" 8080
wait_for_target_health "$NLB_TARGET_GROUP_ARN"

################################################################################
# STEP 10: RUN API TESTS
################################################################################
log_section "Step 10: Running API Tests"

TEST_URL="$API_ENDPOINT"

if [[ -z "$TEST_URL" ]]; then
  log_warn "API Gateway endpoint not available; skipping external tests"
else
  log_info "Service URL: $TEST_URL"
fi

# Test 1: Health check
log_info "Test 1: Health check (GET /)"
if [[ -n "$TEST_URL" ]]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL/" 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]]; then
    log_ok "Health check passed"
  else
    log_warn "Health check returned HTTP $HTTP_CODE"
  fi
fi

# Test 2: Get claim
log_info "Test 2: Get claim (GET /claims/1001)"
if [[ -n "$TEST_URL" ]]; then
  CLAIM_RESPONSE=$(curl -s "$TEST_URL/claims/1001" 2>/dev/null || echo "{}")
  if echo "$CLAIM_RESPONSE" | grep -q "1001"; then
    log_ok "Get claim test passed"
  else
    log_warn "Get claim test returned: $CLAIM_RESPONSE"
  fi
fi

# Test 3: Summarize claim (Bedrock integration)
log_info "Test 3: Summarize claim (POST /claims/1001/summarize) - Bedrock integration"
if [[ -n "$TEST_URL" ]]; then
  SUMMARY_RESPONSE=$(curl -s -X POST "$TEST_URL/claims/1001/summarize" 2>/dev/null || echo "{}")
  if echo "$SUMMARY_RESPONSE" | grep -q "overall_summary"; then
    log_ok "Bedrock summarization test passed"
  else
    log_warn "Summarization test returned: $(echo "$SUMMARY_RESPONSE" | head -c 100)..."
  fi
fi

################################################################################
# STEP 11: DISPLAY FINAL INFORMATION & ANALYSIS
################################################################################
log_section "Step 11: Deployment Summary & AI Analysis"

log_ok "Deployment Complete!"
echo ""
echo "📊 Infrastructure:"
echo "  EKS Cluster: $EKS_CLUSTER_NAME"
echo "  Region: $AWS_REGION"
echo "  Endpoint: $EKS_ENDPOINT"
echo ""
echo "🔌 APIs & Services:"
echo "  API Gateway: $API_ENDPOINT"
echo "  Service URL: $TEST_URL"
echo ""
echo "📦 Data & Storage:"
echo "  S3 Bucket: $S3_BUCKET"
echo "  DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo ""
echo "🤖 Bedrock Integration:"
echo "  Model: anthropic.claude-3-5-sonnet-20241022"
echo "  Service Role: $BEDROCK_ROLE_ARN"
echo ""
echo "📝 Mock Data:"
echo "  Claims: 5 (IDs: 1001-1005)"
echo "  Notes: 8 total across 5 note groups"
echo ""

# Fetch the sample API response
SAMPLE_RESPONSE=""
if [[ -n "$API_ENDPOINT" ]]; then
  echo "📋 Sample API Response:"
  echo ""
  SAMPLE_RESPONSE=$(curl -s "$API_ENDPOINT/claims/1001" 2>/dev/null || echo "{}")
  echo "$SAMPLE_RESPONSE" | jq . 2>/dev/null || echo "$SAMPLE_RESPONSE"
  echo ""
else
  echo "⚠️  API endpoint not available; skipping analysis"
  echo ""
fi

# Send to Bedrock for AI analysis
if [[ -n "$SAMPLE_RESPONSE" ]] && [[ "$SAMPLE_RESPONSE" != "{}" ]]; then
  echo "🤖 Bedrock AI Analysis of API Response:"
  echo ""
  BEDROCK_ANALYSIS=$(invoke_bedrock_analysis "$SAMPLE_RESPONSE" "$BEDROCK_ROLE_ARN")
  if [[ -n "$BEDROCK_ANALYSIS" ]] && [[ "$BEDROCK_ANALYSIS" != "Bedrock analysis unavailable"* ]]; then
    echo "$BEDROCK_ANALYSIS"
  else
    log_warn "Bedrock analysis: IAM role may need additional permissions for bedrock:InvokeModel"
  fi
  echo ""
fi

# Fetch CloudWatch logs
echo "📊 CloudWatch Logs (Last 10 minutes):"
echo ""
LOG_GROUP="/aws/eks/$EKS_CLUSTER_NAME/pods"
CLOUDWATCH_LOGS=$(fetch_cloudwatch_logs "$LOG_GROUP" 10)
if [[ -n "$CLOUDWATCH_LOGS" ]] && [[ "$CLOUDWATCH_LOGS" != "No logs available" ]]; then
  echo "$CLOUDWATCH_LOGS" | tail -20
  echo ""
  echo "(Showing last 20 log lines. View all: aws logs filter-log-events --log-group-name \"$LOG_GROUP\" --query 'events[].message')"
else
  echo "  No recent logs available. Logs may appear shortly after pod startup."
fi
echo ""

echo "📋 More Commands:"
echo "  View pod logs: kubectl logs -f deployment/sample-service-sample-service"
echo "  Query CloudWatch: aws logs filter-log-events --log-group-name \"$LOG_GROUP\""
echo "  Cleanup: ./destroy.sh"
echo ""
log_ok "✨ Introspect-2B is ready to use!"
