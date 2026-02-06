# 🚀 Deployment Guide - Clone and Deploy

## Overview
This guide provides step-by-step instructions to clone and deploy the Introspect-2B GenAI-enabled Claim Status API in your AWS environment.

**Time Required**: 20-30 minutes  
**Estimated Cost**: ~$130/month

---

## Prerequisites

### 1. Required Tools
Install the following tools before starting:

```bash
# AWS CLI
aws --version  # Should be 2.x or higher

# Terraform
terraform --version  # Should be 1.0 or higher

# Docker
docker --version

# kubectl
kubectl version --client

# Helm
helm version

# jq (for JSON parsing)
jq --version
```

**Installation Links:**
- AWS CLI: https://aws.amazon.com/cli/
- Terraform: https://www.terraform.io/downloads
- Docker: https://docs.docker.com/get-docker/
- kubectl: https://kubernetes.io/docs/tasks/tools/
- Helm: https://helm.sh/docs/intro/install/
- jq: https://stedolan.github.io/jq/download/

### 2. AWS Account Requirements
- Active AWS account
- IAM user with permissions for:
  - EKS, EC2, VPC
  - API Gateway, NLB
  - ECR, S3, DynamoDB
  - IAM (for IRSA)
  - CloudWatch

### 3. AWS CLI Configuration
```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1 (recommended)
# - Default output format: json

# Verify
aws sts get-caller-identity
```

---

## Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/ndeepakprasanth/introspect-2b-dpn.git
cd introspect-2b-dpn

# Make scripts executable
chmod +x *.sh
```

---

## Step 2: Create S3 Bucket for Terraform State

```bash
# Set your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create unique bucket name
export TF_STATE_BUCKET="introspect-tf-state-${AWS_ACCOUNT_ID}-$(date +%s)"

# Create bucket
aws s3 mb s3://$TF_STATE_BUCKET --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $TF_STATE_BUCKET \
  --versioning-configuration Status=Enabled

echo "✅ S3 bucket created: $TF_STATE_BUCKET"
echo "⚠️  SAVE THIS: export TF_STATE_BUCKET=$TF_STATE_BUCKET"
```

**Important**: Save the bucket name - you'll need it for all Terraform operations.

---

## Step 3: Deploy Infrastructure

### Option A: Automated Deployment (Recommended)

```bash
# Set environment variables
export TF_STATE_BUCKET=your-bucket-name  # Use bucket from Step 2
export AWS_REGION=us-east-1

# Run complete deployment
./deploy-and-test.sh
```

This script will:
1. Deploy all infrastructure (10-15 minutes)
2. Upload mock data to S3
3. Build and push Docker image
4. Deploy application to EKS
5. Run API tests

### Option B: Manual Step-by-Step

#### 3.1 Bootstrap Infrastructure
```bash
export TF_STATE_BUCKET=your-bucket-name
export TF_STATE_KEY=instrospect2/dev/terraform.tfstate
export AWS_REGION=us-east-1

./bootstrap-infra.sh
```

#### 3.2 Verify Infrastructure
```bash
cd infra/envs/dev
terraform output

# You should see:
# - api_endpoint
# - ecr_repository_url
# - eks_cluster_name
# - s3_notes_bucket
# - dynamodb_table
# - bedrock_role_arn
```

---

## Step 4: Deploy Application

### 4.1 Upload Mock Data
```bash
# Get S3 bucket name
S3_BUCKET=$(cd infra/envs/dev && terraform output -raw s3_notes_bucket)

# Upload mock data
aws s3 cp mocks/claims.json s3://$S3_BUCKET/claims.json
aws s3 cp mocks/notes.json s3://$S3_BUCKET/notes.json

echo "✅ Mock data uploaded"
```

### 4.2 Build and Push Docker Image
```bash
# Get ECR repository URL
ECR_REPO=$(cd infra/envs/dev && terraform output -raw ecr_repository_url)

# Build image for linux/amd64
cd app/services/sample-service
docker buildx build --platform linux/amd64 -t introspect-sample-service:latest . --load

# Tag image
docker tag introspect-sample-service:latest $ECR_REPO:latest

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $(echo $ECR_REPO | cut -d'/' -f1)

# Push image
docker push $ECR_REPO:latest

cd ../../..
echo "✅ Image pushed to ECR"
```

### 4.3 Deploy to Kubernetes
```bash
# Get cluster name and Bedrock role
EKS_CLUSTER=$(cd infra/envs/dev && terraform output -raw eks_cluster_name)
BEDROCK_ROLE=$(cd infra/envs/dev && terraform output -raw bedrock_role_arn)

# Update kubeconfig
aws eks update-kubeconfig --name $EKS_CLUSTER --region us-east-1

# Verify nodes are ready
kubectl get nodes

# Deploy with Helm
helm upgrade --install sample-service app/services/sample-service \
  -n app --create-namespace \
  --set image.repository=$ECR_REPO \
  --set image.tag=latest \
  --set image.pullPolicy=Always \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$BEDROCK_ROLE \
  --wait --timeout 300s

echo "✅ Application deployed"
```

### 4.4 Verify Deployment
```bash
# Check pods
kubectl get pods -n app

# Should show: 1/1 Running

# Check logs
kubectl logs -f deployment/sample-service-sample-service -n app
```

---

## Step 5: Test API Endpoints

### 5.1 Port Forward to Service
```bash
kubectl port-forward svc/sample-service-sample-service 8080:8080 -n app &
sleep 5
```

### 5.2 Test Endpoints
```bash
# Health check
curl http://localhost:8080/
# Expected: {"message": "Hello from Introspect sample service"}

# Get claim
curl http://localhost:8080/claims/1001 | jq .
# Expected: Claim details for Alice Smith

# Summarize claim (GenAI)
curl -X POST http://localhost:8080/claims/1001/summarize | jq .
# Expected: Summary with overall, customer, adjuster summaries

# Run all tests
./test-api.sh http://localhost:8080
```

### 5.3 Stop Port Forward
```bash
pkill -f "port-forward"
```

---

## Step 6: Verify Infrastructure Components

### 6.1 Check EKS Cluster
```bash
aws eks describe-cluster --name $EKS_CLUSTER --region us-east-1 \
  --query 'cluster.[name,status,version]' --output table
```

### 6.2 Check API Gateway
```bash
API_ENDPOINT=$(cd infra/envs/dev && terraform output -raw api_endpoint)
echo "API Gateway: $API_ENDPOINT"
```

### 6.3 Check S3 Data
```bash
aws s3 ls s3://$S3_BUCKET/
# Should show: claims.json, notes.json
```

### 6.4 Check DynamoDB Table
```bash
DYNAMODB_TABLE=$(cd infra/envs/dev && terraform output -raw dynamodb_table)
aws dynamodb describe-table --table-name $DYNAMODB_TABLE \
  --query 'Table.[TableName,TableStatus]' --output table
```

### 6.5 Check CloudWatch Logs
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/ \
  --query 'logGroups[].logGroupName' --output table
```

---

## Step 7: Access Application

### Via Port Forward (Local Testing)
```bash
kubectl port-forward svc/sample-service-sample-service 8080:8080 -n app
# Access: http://localhost:8080
```

### Via API Gateway (If Configured)
```bash
API_ENDPOINT=$(cd infra/envs/dev && terraform output -raw api_endpoint)
curl $API_ENDPOINT/claims/1001
```

---

## Troubleshooting

### Issue: Pod Not Starting
```bash
# Check pod status
kubectl get pods -n app

# Describe pod
kubectl describe pod <pod-name> -n app

# Check logs
kubectl logs <pod-name> -n app

# Common fixes:
# - Ensure image architecture is linux/amd64
# - Check if node has capacity
# - Verify image was pushed to ECR
```

### Issue: Terraform State Lock
```bash
# Unlock state
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"'$TF_STATE_BUCKET'/instrospect2/dev/terraform.tfstate-md5"}}'
```

### Issue: ECR Login Failed
```bash
# Re-login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
```

### Issue: kubectl Connection Refused
```bash
# Update kubeconfig
aws eks update-kubeconfig --name $EKS_CLUSTER --region us-east-1

# Verify connection
kubectl cluster-info
```

---

## Cleanup

When you're done, clean up resources to avoid charges:

```bash
# 1. Delete Kubernetes resources
helm uninstall sample-service -n app
kubectl delete namespace app

# 2. Destroy infrastructure
cd infra/envs/dev
terraform destroy -auto-approve
cd ../../..

# 3. Delete S3 state bucket (optional)
aws s3 rm s3://$TF_STATE_BUCKET --recursive
aws s3 rb s3://$TF_STATE_BUCKET

# 4. Delete DynamoDB lock table
aws dynamodb delete-table --table-name terraform-locks
```

---

## Environment Variables Reference

```bash
# Required
export TF_STATE_BUCKET=your-bucket-name
export AWS_REGION=us-east-1

# Optional (auto-detected)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_PROFILE=default  # If using named profile
```

---

## Success Criteria

✅ Infrastructure deployed (EKS, API Gateway, NLB, etc.)  
✅ Application pod running (1/1)  
✅ API endpoints responding  
✅ Mock data accessible  
✅ CloudWatch logs flowing  
✅ All tests passing  

---

## Cost Optimization

**Estimated Monthly Cost**: ~$130
- EKS Control Plane: $73
- EC2 t3.small: $15
- NLB: $16
- Other services: $26

**To Reduce Costs:**
- Use smaller instance types
- Delete resources when not in use
- Use Fargate instead of EC2 (if suitable)

---

## Support

- **Documentation**: See PROJECT_README.md
- **Issues**: https://github.com/ndeepakprasanth/introspect-2b-dpn/issues
- **Quick Reference**: QUICK_REFERENCE.md

---

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Test API endpoints
3. 📸 Take screenshots for submission
4. 📝 Review SUBMISSION_REPORT.md
5. 🚀 Submit project

---

**Deployment Time**: 20-30 minutes  
**Difficulty**: Intermediate  
**Status**: Production-ready

*Last Updated: February 6, 2026*
