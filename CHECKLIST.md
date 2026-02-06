# Pre-Deployment Checklist

Use this checklist before pushing to GitHub and deploying.

## Prerequisites

- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Docker installed and running
- [ ] kubectl installed
- [ ] Helm 3 installed
- [ ] jq installed
- [ ] Git configured

## AWS Setup

- [ ] AWS credentials configured (`aws sts get-caller-identity` works)
- [ ] S3 bucket created for Terraform state
- [ ] Bucket name saved (you'll need it for deployment)
- [ ] IAM permissions verified (EKS, EC2, S3, DynamoDB, ECR, etc.)

## Repository Setup

- [ ] Repository cloned locally
- [ ] All scripts are executable (`chmod +x *.sh`)
- [ ] `.gitignore` in place
- [ ] No sensitive data in repository (credentials, keys, etc.)

## Configuration Review

- [ ] Review `infra/envs/dev/variables.tf` - region correct?
- [ ] Review `infra/envs/dev/main.tf` - cluster name correct?
- [ ] Review `app/services/sample-service/values.yaml` - image repository correct?
- [ ] Review `mocks/claims.json` - at least 5 claims present?
- [ ] Review `mocks/notes.json` - at least 3 notes present?

## GitHub Actions (Optional)

If using GitHub Actions:
- [ ] Repository created on GitHub
- [ ] Secrets added to repository:
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `AWS_REGION`
  - [ ] `AWS_ACCOUNT_ID`
  - [ ] `EKS_CLUSTER_NAME`
  - [ ] `TF_STATE_BUCKET`

## Pre-Deployment Tests

- [ ] Terraform syntax check: `cd infra/envs/dev && terraform fmt -check`
- [ ] Python tests pass: `cd app/services/sample-service && pytest`
- [ ] Docker build works: `docker build -t test app/services/sample-service`
- [ ] Helm chart valid: `helm lint app/services/sample-service`

## Deployment

- [ ] Set environment variables:
  ```bash
  export TF_STATE_BUCKET=your-bucket-name
  export AWS_REGION=us-east-1
  ```
- [ ] Run deployment: `./deploy-and-test.sh`
- [ ] Wait for completion (10-15 minutes)

## Post-Deployment Verification

### Infrastructure
- [ ] VPC created with public and private subnets
- [ ] EKS cluster running
- [ ] EC2 worker nodes in node group
- [ ] ECR repository created
- [ ] S3 bucket created
- [ ] DynamoDB table created
- [ ] API Gateway created
- [ ] NLB created
- [ ] Security groups configured

### Kubernetes
- [ ] Pods running: `kubectl get pods -n default`
- [ ] Service created: `kubectl get svc -n default`
- [ ] Deployment healthy: `kubectl get deployment -n default`
- [ ] ServiceAccount has IRSA annotation: `kubectl describe sa sample-service -n default`

### Security
- [ ] Inspector enabled: Check AWS Console → Inspector
- [ ] Security Hub enabled: Check AWS Console → Security Hub
- [ ] ECR scan completed: Check ECR repository in console
- [ ] Findings visible (if any): Check Inspector/Security Hub

### Observability
- [ ] CloudWatch log groups created:
  - [ ] `/aws/apigateway/introspect-claims-api`
  - [ ] `/aws/eks/introspect-dpn-eks/cluster`
  - [ ] `/aws/containerinsights/introspect-dpn-eks/application`
- [ ] Logs flowing: Check CloudWatch Logs in console
- [ ] Dashboard created: Check CloudWatch Dashboards

### API Testing
- [ ] Health endpoint works: `curl http://localhost:8080/` (via port-forward)
- [ ] GET /claims/1001 works
- [ ] GET /claims/1002 works
- [ ] POST /claims/1001/summarize works
- [ ] API Gateway endpoint accessible (if public)

### Data
- [ ] Mock data uploaded to S3
- [ ] Claims data accessible
- [ ] Notes data accessible

## Documentation

- [ ] `PROJECT_README.md` reviewed and accurate
- [ ] `SETUP.md` reviewed and accurate
- [ ] `IMPLEMENTATION_SUMMARY.md` reviewed
- [ ] `QUICK_REFERENCE.md` reviewed
- [ ] `apigw/api-spec.json` accurate
- [ ] `observability/logs-insights-queries.md` complete
- [ ] `scans/README.md` complete

## Screenshots (for scans/ directory)

- [ ] Inspector findings screenshot
- [ ] Security Hub dashboard screenshot
- [ ] Vulnerability details screenshot
- [ ] CloudWatch logs screenshot (optional)
- [ ] API Gateway metrics screenshot (optional)

## Final Checks

- [ ] All tests pass: `./test-api.sh http://localhost:8080`
- [ ] No errors in pod logs: `kubectl logs deployment/sample-service -n default`
- [ ] No errors in CloudWatch logs
- [ ] Terraform state saved to S3
- [ ] All resources tagged appropriately

## Git Commit

- [ ] All changes staged: `git add .`
- [ ] Meaningful commit message prepared
- [ ] No sensitive data in commit
- [ ] `.gitignore` working correctly

## Push to GitHub

```bash
git add .
git commit -m "Complete GenAI-enabled Claim Status API implementation

- Infrastructure: EKS, API Gateway, NLB, Security, Observability
- Application: Flask API with Bedrock integration
- CI/CD: GitHub Actions and CodePipeline
- Security: Inspector and Security Hub
- Observability: CloudWatch logs and metrics
- Documentation: Complete setup and usage guides
- Automation: One-script deployment and testing"

git push origin main
```

## Lab Submission Checklist

Verify repository contains:
- [x] `src/` - Service source + Dockerfile
- [x] `mocks/claims.json` - 5+ claim records
- [x] `mocks/notes.json` - 3+ notes blobs
- [x] `apigw/` - API Gateway policy files
- [x] `infra/` - Terraform templates
- [x] `pipelines/` - AWS pipeline (CodeBuild/CodePipeline)
- [x] `scans/` - Security findings documentation
- [x] `observability/` - Logs Insight queries
- [x] `README.md` - Instructions and GenAI prompts

## Success Criteria

- [ ] EKS cluster running with EC2 nodes
- [ ] Application pods healthy
- [ ] API endpoints functional via API Gateway
- [ ] Bedrock integration working (or stub fallback)
- [ ] CI/CD pipeline configured
- [ ] Container scanning enabled
- [ ] Logs and metrics visible
- [ ] Documentation complete
- [ ] One-script deployment works
- [ ] Tests pass

## Troubleshooting

If any check fails, refer to:
- `SETUP.md` - Setup instructions
- `PROJECT_README.md` - Troubleshooting section
- `QUICK_REFERENCE.md` - Common commands
- Pod logs: `kubectl logs -f deployment/sample-service -n default`
- Terraform output: `cd infra/envs/dev && terraform output`

## Cleanup (After Lab)

When done with the lab:
```bash
# Delete Kubernetes resources
helm uninstall sample-service -n default

# Destroy infrastructure
cd infra/envs/dev
terraform destroy -auto-approve

# Delete S3 state bucket (optional)
aws s3 rb s3://$TF_STATE_BUCKET --force
```

## Notes

- Deployment takes 10-15 minutes
- EKS cluster creation is the longest step (~10 min)
- Inspector scans trigger automatically on ECR push
- Security Hub findings may take a few minutes to appear
- API Gateway endpoint is publicly accessible by default
- Costs: ~$100-150/month for dev environment

## Support

If you encounter issues:
1. Check this checklist
2. Review `SETUP.md` troubleshooting section
3. Check AWS Console for resource status
4. Review CloudWatch logs
5. Check GitHub Issues (if applicable)

---

**Ready to deploy?** Run: `./deploy-and-test.sh`

**Ready to push?** Run: `git push origin main`
