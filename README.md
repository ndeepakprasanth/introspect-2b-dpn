# Introspect-2B — GenAI-Enabled Claim Status API

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20Bedrock-orange.svg)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A complete, production-ready GenAI-enabled claim status API built on AWS using Amazon EKS (EC2), API Gateway, and Amazon Bedrock with Claude 3.5 Sonnet.

> **✅ Status:** Fully deployed and tested with working Bedrock integration using Claude 3.5 Sonnet model

## ✨ Quick Start (3 Steps)

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/Introspect-2B.git
cd Introspect-2B

# 2. Configure AWS (one-time setup)
aws configure  # Enter your AWS credentials

# 3. Deploy everything
TF_STATE_BUCKET=my-introspect-$(date +%s) ./deploy-and-test.sh
```

**That's it!** The script handles:
- ✅ Prerequisites validation (AWS CLI, Terraform, Docker, kubectl, Helm, jq)
- ✅ AWS infrastructure setup (VPC, EKS, Load Balancer, etc.)
- ✅ Docker image build & push to ECR
- ✅ Application deployment to Kubernetes
- ✅ API endpoint testing
- ✅ Security scanning (Inspector)
- ✅ Observability configuration

**Estimated time:** 15-20 minutes

---

## 📋 Prerequisites

### Required Software (Install via Homebrew on macOS or package manager on Linux)

```bash
# macOS
brew install awscli terraform docker kubectl helm jq

# Linux (Ubuntu/Debian)
sudo apt-get install awscli terraform docker.io kubectl helm jq

# Verify installation
aws --version       # AWS CLI 2.x
terraform --version # Terraform 1.5+
docker --version    # Docker 20.x+
kubectl version     # kubectl 1.28+
helm version        # Helm 3.x+
jq --version        # jq 1.6+
```

### AWS Account Requirements

- ✅ AWS Account with billing enabled
- ✅ Appropriate IAM permissions (see [SETUP.md](SETUP.md#iam-permissions))
- ✅ AWS CLI already configured: `aws configure`
- ✅ Default region set (or use `AWS_REGION=us-east-1`)

### System Requirements

- **Disk Space:** 20 GB free
- **Memory:** 4 GB minimum
- **Network:** Stable internet connection

---

## 🎯 What Gets Deployed

### Infrastructure (Terraform)
Fully automated infrastructure as code creating:

| Component | Purpose |
|-----------|---------|
| **VPC** | Private network for EKS cluster |
| **EKS Cluster** | Kubernetes control plane |
| **EC2 Nodes** | Kubernetes worker nodes (t3.small) |
| **API Gateway** | External REST API entry point |
| **Network Load Balancer** | Internal traffic routing |
| **DynamoDB** | Claim status data storage |
| **S3** | Claim notes storage |
| **ECR** | Container image registry |
| **Inspector** | Automated vulnerability scanning |
| **Security Hub** | Centralized security findings |
| **CloudWatch** | Logs, metrics, dashboards |

### 🤖 Bedrock Integration

The application uses **Amazon Bedrock** with **Claude 3.5 Sonnet** for intelligent claim summarization:

```
✅ Model: anthropic.claude-3-5-sonnet-20241022 (Claude 3.5 Sonnet)
✅ Auth: IRSA (IAM Roles for Service Accounts)
✅ Security: Pod-based role assumption via OIDC
✅ No credentials in containers
```

**How It Works:**
1. Pod assumes IAM role via IRSA (secure token exchange)
2. Application calls Bedrock API with claim data
3. Claude generates intelligent summary with:
   - Customer-facing summary
   - Adjuster-focused details  
   - Recommended next steps
4. Summarized response returned to API client

**Test the Integration:**
```bash
curl -X POST https://your-api-endpoint/claims/1001/summarize | jq .
```

### Application
Flask REST API with GenAI capabilities:

```
POST /claims/{id}/summarize
├── Reads claim notes from S3
├── Invokes Amazon Bedrock (Claude 3.5 Sonnet)
└── Returns:
    ├── overall_summary (full claim overview)
    ├── customer_summary (customer-facing text)
    ├── adjuster_summary (adjuster-focused details)
    └── recommended_next_step (action item)

GET /claims/{id}
└── Returns claim status from DynamoDB
```

### Security & Observability
- **IRSA:** Secure Bedrock access from pods
- **Image Scanning:** Amazon Inspector on ECR push
- **CloudWatch Logs:** All API and application logs
- **Dashboard:** Real-time metrics visualization

---

## 🚀 Deployment Instructions

### Step 1: Clone Repository (5 seconds)

```bash
git clone https://github.com/yourusername/Introspect-2B.git
cd Introspect-2B
```

### Step 2: Verify Prerequisites (2 minutes)

```bash
# This will be run automatically, but you can verify manually:
./prerequisites.sh
```

Expected output:
```
✅ AWS CLI configured
✅ Terraform available
✅ Docker daemon running
✅ kubectl installed
✅ Helm 3 available
✅ jq installed
```

### Step 3: Launch Deployment (15-20 minutes)

```bash
# Create unique S3 bucket for Terraform state
TF_STATE_BUCKET=introspect-tf-state-$(date +%s) ./deploy-and-test.sh
```

Or with custom AWS profile:
```bash
AWS_PROFILE=myprofile TF_STATE_BUCKET=my-state-bucket ./deploy-and-test.sh
```

**What happens during deployment:**
```
✅ Validates existing resources
✅ Checks for required tools
✅ Creates S3 backend for Terraform state
✅ Initializes Terraform
✅ Applies infrastructure (5-10 min)
✅ Builds Docker image
✅ Pushes to ECR (triggers Inspector scan)
✅ Deploys application to EKS
✅ Mounts mock data
✅ Tests API endpoints
✅ Displays Inspector findings
✅ Shows CloudWatch log groups
✅ Provides next steps
```

---

## 🧪 Testing the Deployment

### Test 1: Local Service (via Port-Forward)

```bash
# In one terminal, port-forward to service
kubectl port-forward svc/sample-service-sample-service 8080:8080

# In another terminal, test endpoints
curl http://localhost:8080/claims/1001 | jq .
curl -X POST http://localhost:8080/claims/1001/summarize | jq .
```

### Test 2: API Gateway (External Access)

```bash
# Get API Gateway endpoint
API_ENDPOINT=$(cd iac/envs/dev && terraform output -raw api_endpoint)

# Test GET endpoint
curl $API_ENDPOINT/claims/1001 | jq .

# Test POST endpoint
curl -X POST $API_ENDPOINT/claims/1001/summarize | jq .
```

### Test 3: Verify Security Scanning

```bash
# Check Inspector findings
aws inspector2 list-findings \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"EQUALS","value":"introspect-sample-service"}]}' \
  --region us-east-1

# Check Security Hub
aws securityhub get-findings \
  --filters '{"ResourceId":[{"Value":"introspect-sample-service","Comparison":"CONTAINS"}]}' \
  --region us-east-1
```

### Test 4: Verify Observability

```bash
# Get pod logs
POD=$(kubectl get pods -n default -l app.kubernetes.io/instance=sample-service -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD -n default --tail=50

# List CloudWatch log groups
aws logs describe-log-groups --region us-east-1
```

---

## 📊 API Reference

### Endpoint 1: Get Claim Status

**Request:**
```bash
GET /claims/{id}
```

**Response (200 OK):**
```json
{
  "id": "1001",
  "status": "OPEN",
  "policyNumber": "PN-0001",
  "claimant": "Alice Smith",
  "amount": 1200.50
}
```

**Response (404 Not Found):**
```json
{
  "error": "claim not found"
}
```

---

### Endpoint 2: Summarize Claim with GenAI

**Request:**
```bash
POST /claims/{id}/summarize
```

**Response (200 OK):**
```json
{
  "claimId": "1001",
  "notesCount": 2,
  "summary": {
    "overall_summary": "Customer reported vehicle damage in parking lot, estimated damage $1,200.",
    "customer_summary": "We have received your claim. Our adjuster will contact you within 2 business days.",
    "adjuster_summary": "Review photos. Estimate shows structural damage. Schedule inspection.",
    "recommended_next_step": "Contact customer to schedule inspection appointment"
  }
}
```

---

## 🔒 Security Features

### Container Image Scanning
- **Amazon Inspector** automatically scans images on ECR push
- Detects vulnerabilities in dependencies
- Severity levels: Critical, High, Medium, Low
- Findings aggregated in Security Hub

### Network Security
- **VPC Isolation:** EKS runs in private subnets
- **Security Groups:** Restrictive inbound/outbound rules
- **VPC Link:** Encrypted connection from API Gateway to NLB

### IAM Security
- **IRSA:** Pods assume IAM roles (no hardcoded credentials)
- **Least Privilege:** Minimal permissions for Bedrock access
- **No Console Access:** Application doesn't need AWS console permissions

### Compliance
- **AWS Security Hub:** Integrates with AWS Foundational Security Best Practices
- **CloudWatch Logs:** Audit trail of API requests
- **Encryption:** In transit (TLS) and at rest (managed keys)

---

## 📊 Observability

### CloudWatch Logs
Pre-built queries available in [observability/logs-insights-queries.md](observability/logs-insights-queries.md):

```bash
# API error rate
fields @timestamp, @message | stats count() as errors by @message

# Bedrock API latency
fields @duration | stats avg(@duration), max(@duration)

# Claim summarization requests
fields claimId, @duration | sort @duration desc
```

### CloudWatch Metrics
- **API Gateway:** Request count, latency, error rate
- **EKS:** Node CPU, memory, network
- **Application:** Custom metrics for Bedrock calls

### Dashboards
Automatically created during deployment for visualization of:
- API performance
- Infrastructure health
- Security findings
- Cost tracking

---

## 🗑️ Cleanup & Cost

### Destroy All Resources

```bash
./destroy.sh
```

**This will:**
- Delete EKS cluster (node groups, pods)
- Delete all AWS resources (DynamoDB, ECR, S3, etc.)
- Run Terraform destroy
- Delete Terraform state bucket
- Remove security groups

**Time:** 10-15 minutes

**Cost After Cleanup:** $0/month

### Force Cleanup (if destroy.sh fails)

```bash
./force-cleanup.sh
```

---

## 💰 Cost Estimate

**Monthly Cost (Development):** ~$130

| Component | Cost |
|-----------|------|
| EKS Control Plane | $73 |
| EC2 t3.small (730 hrs) | $15 |
| Network Load Balancer | $16 |
| DynamoDB (on-demand) | $2 |
| CloudWatch Logs | $20 |
| **Total** | **~$130** |

**Ways to reduce costs:**
- Use t3.nano instead of t3.small: -$10/month
- Stop cluster when not in use (manual)
- Use Spot instances for nodes (not covered in this lab)

---

## 📁 Repository Structure

```
Introspect-2B/
│
├── README.md                           # This file
├── QUICK_REFERENCE.md                  # Common commands
├── SETUP.md                            # Detailed setup guide
├── ARCHITECTURE.md                     # Architecture diagrams
├── IMPLEMENTATION_SUMMARY.md           # Implementation details
├── PROJECT_README.md                   # Comprehensive project docs
│
├── deploy-and-test.sh                  # Main deployment script ⭐
├── destroy.sh                          # Cleanup script
├── force-cleanup.sh                    # Manual cleanup fallback
├── prerequisites.sh                    # Validation script
├── bootstrap-infra.sh                  # Terraform initialization
│
├── iac/                                # Terraform Infrastructure as Code
│   ├── envs/
│   │   └── dev/
│   │       ├── main.tf                 # Environment configuration
│   │       ├── providers.tf            # AWS provider & backend
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── modules/
│       ├── api-gateway/                # API Gateway configuration
│       ├── dynamodb/                   # DynamoDB table
│       ├── ecr/                        # ECR repository
│       ├── eks/                        # EKS cluster
│       ├── iam/                        # IAM roles (Bedrock access)
│       ├── nlb/                        # Network Load Balancer
│       ├── node_group/                 # EKS node group (EC2)
│       ├── observability/              # CloudWatch setup
│       ├── pipeline/                   # CI/CD setup
│       ├── s3/                         # S3 buckets
│       ├── security/                   # Security scanning setup
│       └── vpc/                        # VPC & networking
│
├── app/services/
│   └── sample-service/
│       ├── app.py                      # Flask API
│       ├── bedrock_client.py           # Bedrock integration
│       ├── bedrock_stub.py             # Stub implementation
│       ├── Dockerfile                  # Container image
│       ├── requirements.txt            # Python dependencies
│       ├── Chart.yaml                  # Helm chart
│       ├── values.yaml                 # Helm values
│       │
│       ├── templates/                  # Kubernetes manifests
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── serviceaccount.yaml
│       │
│       └── tests/                      # Unit tests
│           ├── test_app.py
│           ├── test_bedrock_client.py
│           └── test_bedrock_integration.py
│
├── apigw/                              # API Gateway configuration
│   ├── api-spec.json                   # OpenAPI specification
│   └── resource-policy.json            # IAM policy
│
├── mocks/                              # Test data
│   ├── claims.json                     # 5 claim records
│   └── notes.json                      # 3-4 notes per claim
│
├── observability/                      # CloudWatch queries
│   └── logs-insights-queries.md        # Pre-built Logs Insights queries
│
├── scans/                              # Security scanning docs
│   └── README.md                       # Inspector & Security Hub guide
│
└── pipelines/                          # CI/CD configuration
    └── buildspec.yml                   # CodeBuild specification
```

---

## 🤖 GenAI Integration Details

### Model: Amazon Bedrock

**Model Used:** Claude 3 Sonnet (configurable)

```bash
MODEL_ID=amazon.titan-text-express-v1  # Default
# Or use
MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
```

### Prompt Engineering

The application sends claim notes to Bedrock with this system prompt:

```
You are an insurance claims assistant. Given the following claim notes, 
produce a JSON object with the following fields: 
  - overall_summary: Brief overview of the claim
  - customer_summary: Customer-facing explanation
  - adjuster_summary: Internal notes for adjuster
  - recommended_next_step: Action item
Keep summaries concise (1-3 sentences).
```

### Authentication

- **Method:** IAM Roles for Service Accounts (IRSA)
- **No API Keys:** Application inherits AWS credentials via Kubernetes
- **Least Privilege:** Role has only `bedrock:InvokeModel` permission

---

## 🔧 Troubleshooting

### Issue: "EKS cluster already exists"

**Cause:** Previous deployment still exists

**Solution:**
```bash
ALLOW_EXISTING=true ./deploy-and-test.sh
# OR
./destroy.sh && TF_STATE_BUCKET=my-new-state ./deploy-and-test.sh
```

---

### Issue: "Failed to pull image"

**Cause:** Image not pushed to ECR yet

**Solution:**
```bash
# Check image exists in ECR
aws ecr describe-images --repository-name introspect-sample-service

# Manually rebuild
cd app/services/sample-service
docker buildx build --platform linux/amd64 -t $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com/introspect-sample-service:latest --push .
```

---

### Issue: "API Gateway endpoint returns 502"

**Cause:** Service not fully ready yet

**Solution:**
```bash
# Check pod status
kubectl get pods -n default

# Check pod logs
POD=$(kubectl get pods -n default -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=sample-service -n default --timeout=300s
```

---

### Issue: Bedrock "Access Denied" error

**Cause:** IRSA role not configured correctly

**Solution:**
```bash
# Verify service account annotation
kubectl get sa sample-service -n default -o yaml

# Check role ARN
cd iac/envs/dev && terraform output bedrock_role_arn

# Verify role has Bedrock policy
aws iam get-role-policy --role-name sample-service-bedrock-role --policy-name bedrock-invoke
```

---

See [SETUP.md](SETUP.md#troubleshooting) for more detailed troubleshooting.

---

## 📚 Documentation Map

| Document | Purpose |  
|----------|---------|
| **README.md** (this file) | Quick start & overview |
| **[SETUP.md](SETUP.md)** | Detailed setup & troubleshooting |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Design, diagrams, trade-offs |
| **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** | Common commands cheat sheet |
| **[PROJECT_README.md](PROJECT_README.md)** | Comprehensive project details |
| **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** | What was implemented & why |
| **[CHECKLIST.md](CHECKLIST.md)** | Pre-deployment verification |
| **[scans/README.md](scans/README.md)** | Security scanning (Inspector, Security Hub) |
| **[observability/logs-insights-queries.md](observability/logs-insights-queries.md)** | CloudWatch queries |

---

## ✅ Lab Requirements Checklist

This implementation meets **all** lab requirements:

- ✅ **EKS with EC2:** Running on t3.small EC2 instances, not Fargate
- ✅ **API Gateway:** REST API exposed via API Gateway + VPC Link
- ✅ **Bedrock Integration:** Claude model for summarization
- ✅ **Endpoints:** GET /claims/{id}, POST /claims/{id}/summarize
- ✅ **Data Stores:** DynamoDB (claims), S3 (notes)
- ✅ **CI/CD:** CodePipeline + CodeBuild with inspection
- ✅ **Container Scanning:** Amazon Inspector on ECR push
- ✅ **Security Hub:** Integrated findings aggregation
- ✅ **CloudWatch:** Logs, metrics, dashboards
- ✅ **One-Command Deploy:** `./deploy-and-test.sh`
- ✅ **Mock Data:** 5+ claims, 3+ notes blobs
- ✅ **Documentation:** Complete README, setup, architecture
- ✅ **All Deliverables:** src/, mocks/, apigw/, iac/, pipelines/, scans/, observability/

---

## 🆘 Need Help?

1. **Before deploying:** Review [SETUP.md](SETUP.md)
2. **During deployment:** Check terminal output, re-run with `-v` flag
3. **After deployment:** Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
4. **Still stuck:** See troubleshooting in [SETUP.md](SETUP.md)

---

## 🎓 Learning Outcomes

By deploying this project, you'll understand:

- ✅ Kubernetes on AWS (EKS)
- ✅ Infrastructure as Code (Terraform)
- ✅ Container image security (Inspector)
- ✅ API Gateway integration
- ✅ GenAI integration patterns
- ✅ Observability and monitoring
- ✅ CI/CD automation
- ✅ AWS security best practices

---

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🚀 Ready to Deploy?

```bash
# Start your Introspect-2B deployment:
TF_STATE_BUCKET=introspect-$(date +%s) ./deploy-and-test.sh
```

**Estimated time:** 15-20 minutes  
**After deploy:** Check logs with `./QUICK_REFERENCE.md`  
**When done:** Run `./destroy.sh` to clean up (saves costs)

---

**Questions?** → Check [SETUP.md](SETUP.md) or open an issue  
**Want details?** → See [PROJECT_README.md](PROJECT_README.md)  
**Need commands?** → Try [QUICK_REFERENCE.md](QUICK_REFERENCE.md)  
