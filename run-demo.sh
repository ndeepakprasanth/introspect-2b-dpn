#!/usr/bin/env bash
set -euo pipefail

# One-shot demo script: create nodegroup, build/push image, deploy helm chart and wait for readiness.
# Usage: TF_STATE_BUCKET=... AWS_PROFILE=... ./run-demo.sh

AWS_PROFILE=${AWS_PROFILE:-Deepak}
AWS_REGION=${AWS_REGION:-us-east-1}
TF_STATE_BUCKET=${TF_STATE_BUCKET:-instrospect2b-dpn-state-bucket}
TF_STATE_KEY=${TF_STATE_KEY:-instrospect2/dev/terraform.tfstate}
DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-locks}
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-introspect-dpn-eks}

# Determine repo root (script dir)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text --profile "$AWS_PROFILE" --region "$AWS_REGION")}
IMAGE_TAG=${IMAGE_TAG:-latest}
ECR_REPO=${ECR_REPO:-$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/introspect-sample-service}

echo "Using AWS_PROFILE=$AWS_PROFILE AWS_REGION=$AWS_REGION EKS_CLUSTER_NAME=$EKS_CLUSTER_NAME"

# 1) Ensure terraform backend configured and create nodegroup
echo "Initializing Terraform (infra/envs/dev) -> using S3 backend $TF_STATE_BUCKET/$TF_STATE_KEY"
terraform -chdir="$REPO_ROOT/infra/envs/dev" init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="key=$TF_STATE_KEY" -backend-config="region=$AWS_REGION" -backend-config="dynamodb_table=$DYNAMODB_TABLE"

echo "Applying Terraform to create node group (this may take several minutes)"
terraform -chdir="$REPO_ROOT/infra/envs/dev" apply -auto-approve

# 2) Build and push Docker image
pushd "$REPO_ROOT/app/services/sample-service" >/dev/null
IMAGE_FULL="$ECR_REPO:$IMAGE_TAG"

echo "Building image $IMAGE_FULL"
docker build -t introspect-sample-service:$IMAGE_TAG .

echo "Tagging and pushing to ECR: $IMAGE_FULL"
docker tag introspect-sample-service:$IMAGE_TAG $IMAGE_FULL
aws ecr get-login-password --region $AWS_REGION --profile "$AWS_PROFILE" | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker push $IMAGE_FULL
popd >/dev/null

# 3) Update kubeconfig and deploy Helm chart
echo "Updating kubeconfig for cluster $EKS_CLUSTER_NAME"
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE"

echo "Installing/upgrading Helm release 'sample-service'"
helm upgrade --install sample-service "$REPO_ROOT/app/services/sample-service" -n default --create-namespace \
  --set image.repository="$ECR_REPO" --set image.tag="$IMAGE_TAG" --wait --timeout 300s

# 4) Wait for pods to be ready
echo "Waiting for deployment sample-service rollout to finish"
kubectl rollout status deployment/sample-service -n default --timeout=300s

echo "Demo deployment complete. Pods:"
kubectl get pods -n default -o wide

echo "Done. If labs reset every 4 hours, run this script again to recreate nodegroup + redeploy the service."