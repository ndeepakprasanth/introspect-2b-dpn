# Setup Guide

This guide walks you through setting up the Introspect-2B project from scratch.

## Prerequisites Installation

### 1. AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

### 2. Terraform
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform --version
```

### 3. Docker
```bash
# macOS
brew install --cask docker

# Linux
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verify
docker --version
```

### 4. kubectl
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

### 5. Helm
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

### 6. jq (for JSON parsing)
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq

# Verify
jq --version
```

## AWS Configuration

### 1. Configure AWS Credentials
```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### 2. Verify AWS Access
```bash
aws sts get-caller-identity
```

### 3. Create S3 Bucket for Terraform State
```bash
# Choose a unique bucket name
BUCKET_NAME="my-introspect-tf-state-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

echo "Your Terraform state bucket: $BUCKET_NAME"
# Save this bucket name for later use
```

## Project Setup

### 1. Clone Repository
```bash
git clone <your-repo-url>
cd Instrospect-2B
```

### 2. Make Scripts Executable
```bash
chmod +x bootstrap-infra.sh
chmod +x deploy-and-test.sh
chmod +x run-demo.sh
chmod +x test-api.sh
```

### 3. Review Configuration
Edit `infra/envs/dev/variables.tf` if needed:
```hcl
variable "region" {
  default = "us-east-1"  # Change if needed
}
```

## Deployment

### Option 1: Automated Deployment (Recommended)
```bash
# Set your S3 bucket name
export TF_STATE_BUCKET="your-bucket-name"

# Run complete deployment
./deploy-and-test.sh
```

This script will:
1. Create all infrastructure
2. Upload mock data
3. Build and push Docker image
4. Deploy to EKS
5. Run tests

### Option 2: Step-by-Step Deployment

#### Step 1: Bootstrap Infrastructure
```bash
TF_STATE_BUCKET=your-bucket-name \
TF_STATE_KEY=instrospect2/dev/terraform.tfstate \
AWS_REGION=us-east-1 \
./bootstrap-infra.sh
```

#### Step 2: Get Infrastructure Outputs
```bash
cd infra/envs/dev
terraform output
cd ../../..
```

#### Step 3: Upload Mock Data
```bash
S3_BUCKET=$(cd infra/envs/dev && terraform output -raw s3_notes_bucket)
aws s3 cp mocks/claims.json s3://$S3_BUCKET/claims.json
aws s3 cp mocks/notes.json s3://$S3_BUCKET/notes.json
```

#### Step 4: Build and Push Image
```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1
ECR_REPO=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/introspect-sample-service

# Build
docker build -t introspect-sample-service:latest app/services/sample-service

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag and push
docker tag introspect-sample-service:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

#### Step 5: Deploy to EKS
```bash
# Update kubeconfig
aws eks update-kubeconfig --name introspect-dpn-eks --region us-east-1

# Get Bedrock role ARN
BEDROCK_ROLE_ARN=$(cd infra/envs/dev && terraform output -raw bedrock_role_arn)

# Deploy with Helm
helm upgrade --install sample-service app/services/sample-service \
  -n default --create-namespace \
  --set image.repository=$ECR_REPO \
  --set image.tag=latest \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$BEDROCK_ROLE_ARN \
  --wait --timeout 300s
```

#### Step 6: Verify Deployment
```bash
kubectl get pods -n default
kubectl get svc -n default
kubectl logs -f deployment/sample-service -n default
```

## Testing

### Test via Port Forward
```bash
# Start port forward
kubectl port-forward svc/sample-service 8080:8080 -n default &

# Run tests
./test-api.sh http://localhost:8080

# Stop port forward
pkill -f "port-forward"
```

### Test via API Gateway
```bash
API_ENDPOINT=$(cd infra/envs/dev && terraform output -raw api_endpoint)
./test-api.sh $API_ENDPOINT
```

## GitHub Actions Setup (Optional)

### 1. Add Repository Secrets
Go to GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_REGION`: us-east-1 (or your region)
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `EKS_CLUSTER_NAME`: introspect-dpn-eks
- `TF_STATE_BUCKET`: Your S3 bucket name

### 2. Enable Workflows
The workflow at `.github/workflows/complete-cicd.yml` will:
- Run Terraform plan on PRs
- Apply Terraform on merge to main
- Build and deploy application

## Verification Checklist

- [ ] AWS CLI configured and working
- [ ] Terraform installed
- [ ] Docker installed and running
- [ ] kubectl installed
- [ ] Helm installed
- [ ] S3 bucket created for Terraform state
- [ ] Infrastructure deployed successfully
- [ ] EKS cluster accessible
- [ ] Application pods running
- [ ] API endpoints responding
- [ ] Inspector scanning enabled
- [ ] Security Hub configured
- [ ] CloudWatch logs visible

## Troubleshooting

### Terraform State Lock
```bash
# If state is locked
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"<bucket>/<key>-md5"}}'
```

### EKS Access Denied
```bash
# Ensure your IAM user/role has EKS permissions
aws eks describe-cluster --name introspect-dpn-eks --region us-east-1
```

### Docker Build Fails
```bash
# Check Docker is running
docker ps

# Clean up old images
docker system prune -a
```

### Pod Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n default

# Check logs
kubectl logs <pod-name> -n default

# Check events
kubectl get events -n default --sort-by='.lastTimestamp'
```

## Next Steps

1. Review security findings in Inspector
2. Check CloudWatch logs
3. Customize application code
4. Add more test cases
5. Configure monitoring alerts
6. Set up cost budgets

## Support

For issues:
1. Check logs: `kubectl logs -f deployment/sample-service -n default`
2. Review Terraform output: `cd infra/envs/dev && terraform output`
3. Verify AWS resources in console
4. Open GitHub issue with error details
