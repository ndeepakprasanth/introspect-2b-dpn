# Introspect-2B — GenAI-Enabled Claim Status API

A cloud-native application demonstrating GenAI integration on AWS using Amazon EKS, API Gateway, and Amazon Bedrock.

## Architecture Overview

```
Internet → API Gateway → VPC Link → NLB → EKS (EC2) → Application Pod
                                                      ↓
                                            Amazon Bedrock (GenAI)
                                            DynamoDB (Claims)
                                            S3 (Notes)
```

## Key Components

- **Amazon EKS**: Kubernetes control plane with EC2 worker nodes
- **Amazon API Gateway**: HTTP API for external access
- **Network Load Balancer**: Internal routing to EKS services
- **Amazon Bedrock**: GenAI for claim summarization
- **Amazon DynamoDB**: Claim status data store
- **Amazon S3**: Claim notes storage
- **Amazon ECR**: Container image repository
- **AWS CodePipeline/CodeBuild**: CI/CD automation
- **Amazon Inspector**: Container vulnerability scanning
- **AWS Security Hub**: Centralized security findings
- **Amazon CloudWatch**: Logs and metrics

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Docker
- kubectl
- Helm 3
- jq (for testing)

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd Instrospect-2B
chmod +x bootstrap-infra.sh deploy-and-test.sh run-demo.sh
```

### 2. Deploy Infrastructure

**Option A: Interactive**
```bash
./bootstrap-infra.sh
```

**Option B: Non-interactive**
```bash
TF_STATE_BUCKET=my-tf-state-bucket \
TF_STATE_KEY=instrospect2/dev/terraform.tfstate \
AWS_REGION=us-east-1 \
./bootstrap-infra.sh
```

### 3. Complete Deployment and Testing

```bash
./deploy-and-test.sh
```

This script will:
1. Bootstrap infrastructure (VPC, EKS, ECR, S3, DynamoDB, API Gateway, etc.)
2. Upload mock data to S3
3. Build and push Docker image to ECR
4. Deploy application to EKS using Helm
5. Run API tests
6. Display resource URLs and next steps

### 4. Quick Demo (Lab Reset Recovery)

If your lab environment resets, quickly restore with:

```bash
TF_STATE_BUCKET=my-bucket \
AWS_REGION=us-east-1 \
./run-demo.sh
```

## API Endpoints

### GET /claims/{id}
Returns claim status information from DynamoDB.

**Example:**
```bash
curl https://<api-gateway-url>/claims/1001
```

**Response:**
```json
{
  "id": "1001",
  "status": "OPEN",
  "policyNumber": "PN-0001",
  "claimant": "Alice Smith",
  "amount": 1200.50
}
```

### POST /claims/{id}/summarize
Invokes Amazon Bedrock to generate claim summaries.

**Example:**
```bash
curl -X POST https://<api-gateway-url>/claims/1001/summarize
```

**Response:**
```json
{
  "claimId": "1001",
  "notesCount": 3,
  "summary": {
    "overall_summary": "Claim involves vehicle damage...",
    "customer_summary": "Your claim is being processed...",
    "adjuster_summary": "Review photos and estimate...",
    "recommended_next_step": "Schedule vehicle inspection"
  }
}
```

## Directory Structure

```
.
├── apigw/                      # API Gateway configurations
│   ├── api-spec.json          # OpenAPI specification
│   └── resource-policy.json   # Resource policy
├── app/
│   └── services/
│       └── sample-service/    # Application source code
│           ├── app.py         # Flask application
│           ├── bedrock_client.py  # Bedrock integration
│           ├── Dockerfile     # Container definition
│           └── Chart.yaml     # Helm chart
├── infra/                     # Terraform infrastructure
│   ├── envs/dev/             # Development environment
│   └── modules/              # Reusable modules
│       ├── vpc/
│       ├── eks/
│       ├── api-gateway/
│       ├── nlb/
│       ├── ecr/
│       ├── s3/
│       ├── dynamodb/
│       ├── iam/
│       ├── pipeline/
│       ├── security/
│       └── observability/
├── mocks/                     # Mock data
│   ├── claims.json           # Sample claims
│   └── notes.json            # Sample notes
├── observability/            # CloudWatch queries
│   └── logs-insights-queries.md
├── pipelines/                # CI/CD configuration
│   └── buildspec.yml
├── scans/                    # Security scan documentation
│   └── README.md
├── src/                      # Source reference
│   └── README.md
├── bootstrap-infra.sh        # Infrastructure bootstrap
├── deploy-and-test.sh        # Complete deployment
└── run-demo.sh              # Quick demo deployment
```

## Infrastructure Modules

### VPC Module
Creates VPC with public and private subnets across 2 AZs.

### EKS Module
Provisions EKS cluster with EC2 worker nodes (t3.small).

### API Gateway Module
HTTP API with VPC Link integration to internal NLB.

### NLB Module
Network Load Balancer for routing to EKS services.

### IAM Module
IRSA (IAM Roles for Service Accounts) for Bedrock access.

### Security Module
Enables Amazon Inspector and AWS Security Hub.

### Observability Module
CloudWatch Log Groups and dashboards.

## CI/CD Pipeline

The pipeline is defined in `pipelines/buildspec.yml` and includes:

1. **Build Phase**: Run tests, build Docker image
2. **Push Phase**: Push to ECR (triggers Inspector scan)
3. **Deploy Phase**: Deploy to EKS using Helm

### GitHub Actions

Workflow at `.github/workflows/ci-cd.yml` automates:
- Terraform plan on PRs
- Terraform apply on merge to main
- Container build and deployment

**Required Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `AWS_ACCOUNT_ID`
- `EKS_CLUSTER_NAME`
- `TF_STATE_BUCKET`

## Security

### Container Scanning
Amazon Inspector automatically scans ECR images for vulnerabilities.

**View findings:**
```bash
aws inspector2 list-findings \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"EQUALS","value":"introspect-sample-service"}]}' \
  --region us-east-1
```

### Security Hub
Aggregates findings from Inspector and other services.

**View findings:**
```bash
aws securityhub get-findings \
  --filters '{"ResourceId":[{"Value":"introspect-sample-service","Comparison":"CONTAINS"}]}' \
  --region us-east-1
```

See `scans/README.md` for detailed documentation.

## Observability

### CloudWatch Logs

Log groups created:
- `/aws/apigateway/introspect-claims-api` - API Gateway logs
- `/aws/eks/introspect-dpn-eks/cluster` - EKS control plane logs
- `/aws/containerinsights/introspect-dpn-eks/application` - Application logs

### Logs Insights Queries

See `observability/logs-insights-queries.md` for pre-built queries:
- API request analysis
- Error rate tracking
- Response time analysis
- Bedrock invocation tracking

### Viewing Logs

```bash
# Application logs
kubectl logs -f deployment/sample-service -n default

# API Gateway logs (CloudWatch)
aws logs tail /aws/apigateway/introspect-claims-api --follow
```

## Testing

### Local Testing

```bash
cd app/services/sample-service
pip install -r requirements.txt
pytest
python app.py
```

### Integration Testing

```bash
# Port-forward to service
kubectl port-forward svc/sample-service 8080:8080 -n default

# Test endpoints
curl http://localhost:8080/claims/1001
curl -X POST http://localhost:8080/claims/1001/summarize
```

### API Gateway Testing

```bash
API_ENDPOINT=$(cd infra/envs/dev && terraform output -raw api_endpoint)
curl $API_ENDPOINT/claims/1001
curl -X POST $API_ENDPOINT/claims/1001/summarize
```

## GenAI Integration

### Amazon Bedrock Setup

The application uses IRSA to authenticate with Bedrock:

1. IAM role created via `infra/modules/iam`
2. Role ARN annotated on Kubernetes ServiceAccount
3. Application uses AWS SDK with default credential chain

### Bedrock Client

See `app/services/sample-service/bedrock_client.py` for implementation.

**Model used:** Claude 3 Sonnet (configurable via environment variable)

### Fallback Behavior

If Bedrock is unavailable, the application falls back to `bedrock_stub.py` for local testing.

## GenAI Prompts Used in Development

### Infrastructure Design
```
Design a Terraform module structure for a GenAI-enabled API on AWS using:
- Amazon EKS with EC2 nodes
- API Gateway with VPC Link
- Network Load Balancer
- Amazon Bedrock integration via IRSA
- Security scanning with Inspector
- CloudWatch observability

Provide minimal, production-ready modules.
```

### API Gateway Integration
```
Create Terraform configuration for AWS API Gateway HTTP API that:
- Integrates with internal NLB via VPC Link
- Routes GET /claims/{id} and POST /claims/{id}/summarize
- Logs to CloudWatch
- Includes OpenAPI specification

Keep it minimal and functional.
```

### Security Implementation
```
Implement AWS security best practices for EKS application:
- Enable Amazon Inspector for ECR scanning
- Configure Security Hub
- Set up IRSA for Bedrock access
- Create CloudWatch log groups with retention

Provide Terraform modules.
```

### CI/CD Pipeline
```
Create AWS CodeBuild buildspec.yml that:
- Runs Python tests
- Builds Docker image
- Pushes to ECR (triggers Inspector scan)
- Deploys to EKS using Helm
- Includes proper error handling

Make it production-ready.
```

### Observability Queries
```
Generate CloudWatch Logs Insights queries for:
- API request analysis by route
- Error rate tracking
- Response time percentiles
- Top IP addresses
- Bedrock invocation tracking

Provide 8 useful queries.
```

### Documentation
```
Create comprehensive README for GenAI-enabled claim status API including:
- Architecture overview
- Quick start guide
- API documentation
- Security scanning setup
- Observability configuration
- Testing instructions
- GenAI prompts used

Make it clear and actionable.
```

## Troubleshooting

### EKS Node Group Not Ready
```bash
kubectl get nodes
kubectl describe node <node-name>
```

### Pod Not Starting
```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

### API Gateway 502 Error
Check NLB target health:
```bash
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

### Bedrock Access Denied
Verify IRSA configuration:
```bash
kubectl describe sa sample-service -n default
# Check for eks.amazonaws.com/role-arn annotation
```

## Cost Optimization

- EKS cluster: ~$73/month (control plane)
- EC2 t3.small nodes: ~$15/month per node
- API Gateway: Pay per request
- Bedrock: Pay per token
- Other services: Minimal cost

**Estimated monthly cost:** ~$100-150 for dev environment

## Cleanup

```bash
# Delete Kubernetes resources
helm uninstall sample-service -n default

# Destroy infrastructure
cd infra/envs/dev
terraform destroy -auto-approve

# Delete S3 state bucket (if desired)
aws s3 rb s3://<state-bucket> --force
```

## Contributing

1. Create feature branch
2. Make changes
3. Run tests: `pytest app/services/sample-service/tests/`
4. Submit PR (triggers Terraform plan)
5. Merge to main (triggers deployment)

## License

MIT

## Support

For issues or questions, please open a GitHub issue.

---

**Lab Completion Checklist:**
- [x] EKS cluster with EC2 nodes
- [x] API Gateway with VPC Link
- [x] Bedrock integration via IRSA
- [x] DynamoDB and S3 setup
- [x] CI/CD with CodePipeline
- [x] Inspector container scanning
- [x] Security Hub integration
- [x] CloudWatch observability
- [x] Mock data (5+ claims, 3+ notes)
- [x] Complete documentation
- [x] Deployment automation
- [x] Testing scripts
