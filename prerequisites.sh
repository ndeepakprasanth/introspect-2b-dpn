#!/usr/bin/env bash
set -euo pipefail

# --- Require explicit AWS/Terraform context (enterprise-style) ---
AWS_PROFILE=${AWS_PROFILE:-}
AWS_REGION=${AWS_REGION:-}
TF_STATE_BUCKET=${TF_STATE_BUCKET:-}
TF_STATE_KEY=${TF_STATE_KEY:-}
DYNAMODB_TABLE=${DYNAMODB_TABLE:-}

# Bedrock settings (allowed defaults)
# Using Claude 3 Sonnet which is widely available in all regions
MODEL_ID=${MODEL_ID:-anthropic.claude-3-sonnet-20240229-v1:0}
BEDROCK_REGION=${BEDROCK_REGION:-${AWS_REGION:-}}

fail() { echo "❌ $1"; exit 1; }

# Env var checks (no silent defaults)
[ -n "$AWS_PROFILE" ]       || fail "AWS_PROFILE is not set. Export AWS_PROFILE=<your-profile>."
[ -n "$AWS_REGION" ]        || fail "AWS_REGION is not set. Export AWS_REGION=us-east-1."
[ -n "$TF_STATE_BUCKET" ]   || fail "TF_STATE_BUCKET is not set. Export TF_STATE_BUCKET=<your-s3-bucket>."
[ -n "$TF_STATE_KEY" ]      || fail "TF_STATE_KEY is not set. Export TF_STATE_KEY=instrospect2/dev/terraform.tfstate."
[ -n "$DYNAMODB_TABLE" ]    || fail "DYNAMODB_TABLE is not set. Export DYNAMODB_TABLE=terraform-locks."

# Required tools
for CMD in aws terraform docker kubectl helm; do
  command -v "$CMD" >/dev/null 2>&1 || fail "$CMD is not installed or not on PATH."
done
if ! command -v jq >/dev/null 2>&1; then
  echo "ℹ️ jq not found; JSON output will be shown raw."
fi

# AWS credentials sanity
aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1 \
  || fail "AWS credentials for profile '$AWS_PROFILE' are not valid."

# Terraform backend readiness (read-only checks)
aws s3api head-bucket --bucket "$TF_STATE_BUCKET" --profile "$AWS_PROFILE" >/dev/null 2>&1 \
  || fail "S3 bucket '$TF_STATE_BUCKET' not found or not accessible."

aws dynamodb describe-table \
  --table-name "$DYNAMODB_TABLE" \
  --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1 \
  || fail "DynamoDB table '$DYNAMODB_TABLE' not found in region '$AWS_REGION'."

# Bedrock model availability (skip if permissions prevent listing)
if aws bedrock list-foundation-models \
    --region "${BEDROCK_REGION}" --profile "$AWS_PROFILE" \
    --query "modelSummaries[?modelId=='${MODEL_ID}'] | length(@)" \
    --output text >/dev/null 2>&1; then
  count=$(aws bedrock list-foundation-models \
    --region "${BEDROCK_REGION}" --profile "$AWS_PROFILE" \
    --query "modelSummaries[?modelId=='${MODEL_ID}'] | length(@)" \
    --output text 2>/dev/null || echo "0")
  if [ "$count" -lt 1 ]; then
    fail "Bedrock model '${MODEL_ID}' not available in region '${BEDROCK_REGION}'."
  fi
else
  echo "ℹ️ Skipping Bedrock model availability check (insufficient permissions or service not enabled)."
fi

echo "✅ Prerequisites OK."
