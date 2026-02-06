# Quick Reference Card

## One-Command Deployment
```bash
TF_STATE_BUCKET=my-bucket ./deploy-and-test.sh
```

## Common Commands

### Infrastructure
```bash
# Bootstrap infrastructure
./bootstrap-infra.sh

# Quick demo (after lab reset)
./run-demo.sh

# View outputs
cd infra/envs/dev && terraform output

# Destroy infrastructure
cd infra/envs/dev && terraform destroy -auto-approve
```

### Docker
```bash
# Build image
docker build -t introspect-sample-service:latest app/services/sample-service

# Push to ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO=$AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/introspect-sample-service
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker tag introspect-sample-service:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

### Kubernetes
```bash
# Update kubeconfig
aws eks update-kubeconfig --name introspect-dpn-eks --region us-east-1

# View pods
kubectl get pods -n default

# View logs
kubectl logs -f deployment/sample-service -n default

# Describe pod
kubectl describe pod <pod-name> -n default

# Port forward
kubectl port-forward svc/sample-service 8080:8080 -n default

# Restart deployment
kubectl rollout restart deployment/sample-service -n default

# View events
kubectl get events -n default --sort-by='.lastTimestamp'
```

### Helm
```bash
# Deploy
helm upgrade --install sample-service app/services/sample-service -n default

# List releases
helm list -n default

# Uninstall
helm uninstall sample-service -n default

# View values
helm get values sample-service -n default
```

### Testing
```bash
# Test via port-forward
kubectl port-forward svc/sample-service 8080:8080 -n default &
./test-api.sh http://localhost:8080

# Test via API Gateway
API_ENDPOINT=$(cd infra/envs/dev && terraform output -raw api_endpoint)
./test-api.sh $API_ENDPOINT

# Manual tests
curl http://localhost:8080/claims/1001
curl -X POST http://localhost:8080/claims/1001/summarize
```

### Security
```bash
# View Inspector findings
aws inspector2 list-findings \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"EQUALS","value":"introspect-sample-service"}]}' \
  --region us-east-1

# View Security Hub findings
aws securityhub get-findings \
  --filters '{"ResourceId":[{"Value":"introspect-sample-service","Comparison":"CONTAINS"}]}' \
  --region us-east-1
```

### Observability
```bash
# Tail API Gateway logs
aws logs tail /aws/apigateway/introspect-claims-api --follow

# Tail EKS logs
aws logs tail /aws/eks/introspect-dpn-eks/cluster --follow

# View log groups
aws logs describe-log-groups --log-group-name-prefix /aws/

# Run Logs Insights query
aws logs start-query \
  --log-group-name /aws/apigateway/introspect-claims-api \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, requestId, httpMethod, routeKey, status | sort @timestamp desc | limit 20'
```

### S3
```bash
# Upload mock data
S3_BUCKET=$(cd infra/envs/dev && terraform output -raw s3_notes_bucket)
aws s3 cp mocks/claims.json s3://$S3_BUCKET/claims.json
aws s3 cp mocks/notes.json s3://$S3_BUCKET/notes.json

# List bucket contents
aws s3 ls s3://$S3_BUCKET/

# Download file
aws s3 cp s3://$S3_BUCKET/claims.json ./downloaded-claims.json
```

### DynamoDB
```bash
# Get table info
DYNAMODB_TABLE=$(cd infra/envs/dev && terraform output -raw dynamodb_table)
aws dynamodb describe-table --table-name $DYNAMODB_TABLE

# Scan table
aws dynamodb scan --table-name $DYNAMODB_TABLE

# Put item
aws dynamodb put-item --table-name $DYNAMODB_TABLE \
  --item '{"id":{"S":"1001"},"status":{"S":"OPEN"},"amount":{"N":"1200.50"}}'
```

### Git
```bash
# Initial commit
git add .
git commit -m "Initial implementation with complete infrastructure"
git push origin main

# Create feature branch
git checkout -b feature/my-feature
git add .
git commit -m "Add feature"
git push origin feature/my-feature
```

## Environment Variables

```bash
# AWS
export AWS_PROFILE=default
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Terraform
export TF_STATE_BUCKET=my-tf-state-bucket
export TF_STATE_KEY=instrospect2/dev/terraform.tfstate
export DYNAMODB_TABLE=terraform-locks

# EKS
export EKS_CLUSTER_NAME=introspect-dpn-eks

# Image
export IMAGE_TAG=latest
export ECR_REPO=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/introspect-sample-service
```

## Troubleshooting

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check EKS cluster
aws eks describe-cluster --name introspect-dpn-eks --region us-east-1

# Check ECR repository
aws ecr describe-repositories --repository-names introspect-sample-service

# Check S3 bucket
aws s3 ls s3://$(cd infra/envs/dev && terraform output -raw s3_notes_bucket)

# Check DynamoDB table
aws dynamodb describe-table --table-name $(cd infra/envs/dev && terraform output -raw dynamodb_table)

# Unlock Terraform state
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"'$TF_STATE_BUCKET'/'$TF_STATE_KEY'-md5"}}'

# Clean Docker
docker system prune -a

# Reset kubectl context
kubectl config get-contexts
kubectl config use-context <context-name>
```

## URLs

```bash
# Get all important URLs
cd infra/envs/dev
echo "API Gateway: $(terraform output -raw api_endpoint)"
echo "ECR Repository: $(terraform output -raw ecr_repository_url)"
echo "S3 Bucket: $(terraform output -raw s3_notes_bucket)"
echo "DynamoDB Table: $(terraform output -raw dynamodb_table)"
echo "Bedrock Role: $(terraform output -raw bedrock_role_arn)"
```

## File Locations

- Infrastructure: `infra/envs/dev/`
- Application: `app/services/sample-service/`
- Mock Data: `mocks/`
- API Spec: `apigw/`
- Observability: `observability/`
- Security: `scans/`
- CI/CD: `pipelines/`, `.github/workflows/`
- Documentation: `PROJECT_README.md`, `SETUP.md`

## Support

- Documentation: `PROJECT_README.md`
- Setup Guide: `SETUP.md`
- Implementation Details: `IMPLEMENTATION_SUMMARY.md`
- Quick Reference: `QUICK_REFERENCE.md` (this file)
