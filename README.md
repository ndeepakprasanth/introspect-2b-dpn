# Introspect-2B — GenAI-Enabled Claim Status API

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20Bedrock-orange.svg)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)

A production-ready, cloud-native application demonstrating GenAI integration on AWS using Amazon EKS, API Gateway, and Amazon Bedrock.

## 🚀 Quick Start

```bash
# 1. Configure AWS
aws configure

# 2. Create S3 bucket for Terraform state
BUCKET_NAME="my-introspect-tf-state-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# 3. Deploy everything
TF_STATE_BUCKET=$BUCKET_NAME ./deploy-and-test.sh
```

**That's it!** The script will:
- Create all AWS infrastructure (VPC, EKS, API Gateway, etc.)
- Build and push Docker image to ECR
- Deploy application to Kubernetes
- Run API tests
- Display all endpoints and resources

## 📋 What's Included

### Infrastructure (Terraform)
- **Amazon EKS** with EC2 worker nodes
- **API Gateway** with VPC Link integration
- **Network Load Balancer** for internal routing
- **Amazon Bedrock** integration via IRSA
- **DynamoDB** for claim data
- **S3** for claim notes
- **ECR** for container images
- **Inspector** for security scanning
- **Security Hub** for findings aggregation
- **CloudWatch** for logs and metrics

### Application
- Flask-based REST API
- Two endpoints:
  - `GET /claims/{id}` - Get claim status
  - `POST /claims/{id}/summarize` - GenAI summarization
- Amazon Bedrock integration for text summarization
- Kubernetes deployment with Helm

### CI/CD
- GitHub Actions workflow
- AWS CodePipeline/CodeBuild
- Automated testing and deployment
- Container vulnerability scanning

### Documentation
- Complete setup guide
- Architecture diagrams
- API documentation
- Security scanning guide
- Observability queries
- Troubleshooting guide

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [PROJECT_README.md](PROJECT_README.md) | Complete project documentation |
| [SETUP.md](SETUP.md) | First-time setup guide |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Architecture diagrams and flows |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Common commands reference |
| [CHECKLIST.md](CHECKLIST.md) | Pre-deployment checklist |
| [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) | Implementation details |

## 🏗️ Architecture

```
Internet → API Gateway → VPC Link → NLB → EKS (EC2) → Application
                                                      ↓
                                            Amazon Bedrock (GenAI)
                                            DynamoDB (Claims)
                                            S3 (Notes)
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams.

## 🛠️ Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Docker
- kubectl
- Helm 3
- jq

See [SETUP.md](SETUP.md) for installation instructions.

## 📦 Repository Structure

```
.
├── infra/                  # Terraform infrastructure
│   ├── envs/dev/          # Development environment
│   └── modules/           # Reusable modules
│       ├── api-gateway/
│       ├── eks/
│       ├── nlb/
│       ├── security/
│       └── observability/
├── app/services/          # Application code
│   └── sample-service/
├── apigw/                 # API Gateway specs
├── observability/         # CloudWatch queries
├── scans/                 # Security documentation
├── pipelines/             # CI/CD configuration
├── mocks/                 # Mock data
└── *.sh                   # Automation scripts
```

## 🔧 Usage

### Deploy Infrastructure
```bash
./bootstrap-infra.sh
```

### Complete Deployment + Testing
```bash
./deploy-and-test.sh
```

### Quick Demo (Lab Reset Recovery)
```bash
./run-demo.sh
```

### Test API
```bash
./test-api.sh http://localhost:8080
```

## 🧪 API Examples

### Get Claim Status
```bash
curl http://localhost:8080/claims/1001
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

### Summarize Claim
```bash
curl -X POST http://localhost:8080/claims/1001/summarize
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

## 🔒 Security

- **Amazon Inspector**: Automatic container vulnerability scanning
- **AWS Security Hub**: Centralized security findings
- **IRSA**: Secure Bedrock access from Kubernetes
- **VPC**: Private networking for EKS
- **Security Groups**: Network access control

See [scans/README.md](scans/README.md) for details.

## 📊 Observability

- **CloudWatch Logs**: API Gateway, EKS, Application
- **CloudWatch Metrics**: API performance, EKS health
- **Logs Insights**: Pre-built queries for analysis
- **Dashboard**: Real-time metrics visualization

See [observability/logs-insights-queries.md](observability/logs-insights-queries.md) for queries.

## 🤖 GenAI Integration

The application uses Amazon Bedrock (Claude 3 Sonnet) for claim summarization:
- Overall summary
- Customer-facing summary
- Adjuster-focused summary
- Recommended next steps

Authentication via IRSA (IAM Roles for Service Accounts).

## 🔄 CI/CD

### GitHub Actions
Workflow at `.github/workflows/complete-cicd.yml`:
- Terraform plan on PRs
- Terraform apply on main merge
- Build and deploy application

### AWS CodePipeline
Configuration at `pipelines/buildspec.yml`:
- Run tests
- Build Docker image
- Push to ECR (triggers Inspector scan)
- Deploy to EKS

## 💰 Cost Estimate

**Development Environment:** ~$130/month
- EKS Control Plane: $73
- EC2 t3.small: $15
- NLB: $16
- Other services: $26

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed breakdown.

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
helm uninstall sample-service -n default

# Destroy infrastructure
cd infra/envs/dev
terraform destroy -auto-approve

# Delete S3 state bucket (optional)
aws s3 rb s3://$TF_STATE_BUCKET --force
```

## 📝 Lab Requirements

This implementation meets all lab requirements:

✅ EKS cluster with EC2 nodes  
✅ API Gateway integration  
✅ Bedrock GenAI integration  
✅ DynamoDB and S3 data stores  
✅ CI/CD with CodePipeline  
✅ Inspector container scanning  
✅ Security Hub integration  
✅ CloudWatch observability  
✅ Complete documentation  
✅ One-script deployment  
✅ Mock data (5+ claims, 3+ notes)  
✅ All deliverable directories  

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run tests: `pytest app/services/sample-service/tests/`
4. Submit PR

## 📄 License

MIT

## 🆘 Support

- **Documentation**: See docs above
- **Troubleshooting**: [PROJECT_README.md](PROJECT_README.md#troubleshooting)
- **Quick Reference**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Issues**: Open a GitHub issue

## 🎯 Next Steps

1. Review [CHECKLIST.md](CHECKLIST.md) before deployment
2. Run `./deploy-and-test.sh` to deploy
3. Check Inspector and Security Hub for findings
4. Review CloudWatch logs and metrics
5. Test API endpoints
6. Customize application as needed

---

**Ready to deploy?** → `./deploy-and-test.sh`  
**Need help?** → See [SETUP.md](SETUP.md)  
**Want details?** → See [PROJECT_README.md](PROJECT_README.md)

