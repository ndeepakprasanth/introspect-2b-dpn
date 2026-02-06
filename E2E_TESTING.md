# End-to-End Testing Checklist

## ✅ Repository Updated
- [x] Pushed to GitHub: https://github.com/ndeepakprasanth/introspect-2b-dpn
- [x] 48 files changed, 3729 insertions
- [x] All modules and documentation included

## 🚀 Quick Start Testing

### Option 1: Automated E2E Test (Recommended)
```bash
./e2e-test.sh
```

### Option 2: Manual Step-by-Step

#### 1. Prerequisites Check
```bash
# Verify tools
aws --version
terraform --version
docker --version
kubectl version --client
helm version

# Verify AWS access
aws sts get-caller-identity
```

#### 2. Create S3 Bucket for State
```bash
BUCKET_NAME="introspect-tf-state-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

# SAVE THIS!
echo "export TF_STATE_BUCKET=$BUCKET_NAME" >> ~/.bashrc
export TF_STATE_BUCKET=$BUCKET_NAME
```

#### 3. Deploy Infrastructure
```bash
# Full deployment (10-15 minutes)
TF_STATE_BUCKET=$BUCKET_NAME ./deploy-and-test.sh

# OR step-by-step
./bootstrap-infra.sh
# Then build/push image and deploy manually
```

#### 4. Verify Infrastructure
```bash
cd infra/envs/dev

# Check all outputs
terraform output

# Specific outputs
terraform output api_endpoint
terraform output ecr_repository_url
terraform output s3_notes_bucket
terraform output dynamodb_table
terraform output bedrock_role_arn

cd ../../..
```

#### 5. Verify Kubernetes
```bash
# Update kubeconfig
aws eks update-kubeconfig --name introspect-dpn-eks --region us-east-1

# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -n default

# Check service
kubectl get svc -n default

# Check logs
kubectl logs -f deployment/sample-service -n default

# Check service account (should have IRSA annotation)
kubectl describe sa sample-service -n default
```

#### 6. Test API Endpoints

**Via Port Forward:**
```bash
# Start port forward
kubectl port-forward svc/sample-service 8080:8080 -n default &

# Test health
curl http://localhost:8080/

# Test GET /claims/1001
curl http://localhost:8080/claims/1001 | jq .

# Test POST /claims/1001/summarize
curl -X POST http://localhost:8080/claims/1001/summarize | jq .

# Test all endpoints
./test-api.sh http://localhost:8080

# Stop port forward
pkill -f "port-forward"
```

**Via API Gateway (if configured):**
```bash
API_ENDPOINT=$(cd infra/envs/dev && terraform output -raw api_endpoint)
./test-api.sh $API_ENDPOINT
```

#### 7. Verify Security Scanning

**Inspector:**
```bash
# List findings
aws inspector2 list-findings \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"EQUALS","value":"introspect-sample-service"}]}' \
  --region us-east-1 \
  --max-results 10

# Check scan status
aws ecr describe-image-scan-findings \
  --repository-name introspect-sample-service \
  --image-id imageTag=latest \
  --region us-east-1
```

**Security Hub:**
```bash
# List findings
aws securityhub get-findings \
  --filters '{"ResourceId":[{"Value":"introspect-sample-service","Comparison":"CONTAINS"}]}' \
  --region us-east-1 \
  --max-results 10

# Check standards
aws securityhub get-enabled-standards --region us-east-1
```

**Take Screenshots:**
- AWS Console → Inspector → Container image scanning
- AWS Console → Security Hub → Findings
- Save to `scans/` directory

#### 8. Verify Observability

**CloudWatch Log Groups:**
```bash
# List log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/ \
  --region us-east-1

# Tail API Gateway logs
aws logs tail /aws/apigateway/introspect-claims-api --follow

# Tail EKS logs
aws logs tail /aws/eks/introspect-dpn-eks/cluster --follow
```

**CloudWatch Insights:**
```bash
# Run sample query
aws logs start-query \
  --log-group-name /aws/apigateway/introspect-claims-api \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, requestId, httpMethod, routeKey, status | sort @timestamp desc | limit 20'
```

**Dashboard:**
- AWS Console → CloudWatch → Dashboards
- Look for `introspect-dpn-eks-dashboard`

#### 9. Verify Data Stores

**S3:**
```bash
S3_BUCKET=$(cd infra/envs/dev && terraform output -raw s3_notes_bucket)

# List contents
aws s3 ls s3://$S3_BUCKET/

# Verify mock data
aws s3 cp s3://$S3_BUCKET/claims.json - | jq .
aws s3 cp s3://$S3_BUCKET/notes.json - | jq .
```

**DynamoDB:**
```bash
DYNAMODB_TABLE=$(cd infra/envs/dev && terraform output -raw dynamodb_table)

# Describe table
aws dynamodb describe-table --table-name $DYNAMODB_TABLE

# Scan table (if populated)
aws dynamodb scan --table-name $DYNAMODB_TABLE
```

**ECR:**
```bash
# List images
aws ecr describe-images \
  --repository-name introspect-sample-service \
  --region us-east-1

# Check scan findings
aws ecr describe-image-scan-findings \
  --repository-name introspect-sample-service \
  --image-id imageTag=latest \
  --region us-east-1
```

#### 10. Test CI/CD (Optional)

**GitHub Actions:**
1. Go to: https://github.com/ndeepakprasanth/introspect-2b-dpn/actions
2. Check if workflow ran after push
3. Review logs

**CodePipeline:**
```bash
# List pipelines
aws codepipeline list-pipelines --region us-east-1

# Get pipeline status
aws codepipeline get-pipeline-state \
  --name introspect-sample-pipeline \
  --region us-east-1
```

## 📊 Expected Results

### Infrastructure
- ✅ VPC with 2 public + 2 private subnets
- ✅ EKS cluster running
- ✅ 1 EC2 node in node group (t3.small)
- ✅ API Gateway with 2 routes
- ✅ Internal NLB
- ✅ ECR repository with image
- ✅ S3 bucket with mock data
- ✅ DynamoDB table created
- ✅ Inspector enabled
- ✅ Security Hub enabled
- ✅ CloudWatch log groups created

### Application
- ✅ 1 pod running (sample-service)
- ✅ Service exposed on port 8080
- ✅ ServiceAccount with IRSA annotation
- ✅ GET /claims/{id} returns claim data
- ✅ POST /claims/{id}/summarize returns summary

### Security
- ✅ ECR image scanned by Inspector
- ✅ Findings visible in Security Hub
- ✅ No critical vulnerabilities (ideally)

### Observability
- ✅ Logs flowing to CloudWatch
- ✅ Dashboard created
- ✅ Metrics visible

## 🐛 Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
kubectl get events -n default --sort-by='.lastTimestamp'
```

### API Not Responding
```bash
# Check service
kubectl get svc sample-service -n default

# Check endpoints
kubectl get endpoints sample-service -n default

# Check pod logs
kubectl logs -f deployment/sample-service -n default
```

### Terraform Errors
```bash
# Check state
cd infra/envs/dev
terraform state list

# Refresh state
terraform refresh

# Unlock if needed
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"'$TF_STATE_BUCKET'/instrospect2/dev/terraform.tfstate-md5"}}'
```

### Inspector Not Scanning
- Wait 15-30 minutes after image push
- Check ECR console for scan status
- Verify Inspector is enabled in region

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
helm uninstall sample-service -n default

# Destroy infrastructure
cd infra/envs/dev
terraform destroy -auto-approve

# Delete S3 state bucket
aws s3 rm s3://$TF_STATE_BUCKET --recursive
aws s3 rb s3://$TF_STATE_BUCKET

# Delete DynamoDB lock table
aws dynamodb delete-table --table-name terraform-locks
```

## 📸 Screenshots Needed

For `scans/` directory:
1. Inspector findings (ECR scan results)
2. Security Hub dashboard
3. Vulnerability details
4. CloudWatch logs (optional)
5. API Gateway metrics (optional)

## ✅ Final Checklist

- [ ] All infrastructure deployed
- [ ] Application running and accessible
- [ ] API endpoints tested successfully
- [ ] Inspector scan completed
- [ ] Security Hub showing findings
- [ ] CloudWatch logs flowing
- [ ] Screenshots captured
- [ ] Documentation reviewed
- [ ] Ready for submission

## 📝 Notes

- Deployment takes 10-15 minutes
- EKS cluster creation is the longest step
- Inspector scans trigger automatically on ECR push
- Security Hub findings may take a few minutes
- Cost: ~$130/month for dev environment

## 🔗 Resources

- GitHub: https://github.com/ndeepakprasanth/introspect-2b-dpn
- Documentation: See README.md, SETUP.md, PROJECT_README.md
- Quick Reference: QUICK_REFERENCE.md
- Architecture: ARCHITECTURE.md
