#!/bin/bash
# Screenshot Helper - Commands to run for each screenshot

echo "=== Screenshot Helper Guide ==="
echo ""
echo "Create screenshots/ directory first:"
echo "mkdir -p screenshots"
echo ""
echo "Run these commands and take screenshots:"
echo ""

echo "01. EKS Cluster"
echo "   aws eks describe-cluster --name introspect-dpn-eks --region us-east-1"
echo ""

echo "02. EC2 Nodes"
echo "   kubectl get nodes -o wide"
echo ""

echo "03. API Gateway"
echo "   AWS Console → API Gateway → introspect-claims-api"
echo "   OR: cd infra/envs/dev && terraform output api_endpoint"
echo ""

echo "04. Network Load Balancer"
echo "   AWS Console → EC2 → Load Balancers → introspect-nlb"
echo "   OR: cd infra/envs/dev && terraform output nlb_dns_name"
echo ""

echo "05. ECR Repository"
echo "   aws ecr describe-images --repository-name introspect-sample-service --region us-east-1"
echo "   OR: AWS Console → ECR → introspect-sample-service"
echo ""

echo "06. S3 Bucket"
echo "   aws s3 ls s3://introspect-sample-service-notes-9e3c/"
echo "   OR: AWS Console → S3 → introspect-sample-service-notes-9e3c"
echo ""

echo "07. DynamoDB Table"
echo "   aws dynamodb describe-table --table-name introspect-claims --region us-east-1"
echo "   OR: AWS Console → DynamoDB → Tables → introspect-claims"
echo ""

echo "08. IAM Role (IRSA)"
echo "   AWS Console → IAM → Roles → sample-service-bedrock-role"
echo "   Show: Trust relationships (OIDC provider)"
echo ""

echo "09. Kubernetes Deployment"
echo "   kubectl get all -n app"
echo ""

echo "10. Application Logs"
echo "   kubectl logs deployment/sample-service-sample-service -n app --tail=20"
echo ""

echo "11. Health Check"
echo "   kubectl port-forward svc/sample-service-sample-service 8080:8080 -n app &"
echo "   curl http://localhost:8080/ | jq ."
echo ""

echo "12. GET /claims/1001"
echo "   curl http://localhost:8080/claims/1001 | jq ."
echo ""

echo "13. POST /claims/1001/summarize"
echo "   curl -X POST http://localhost:8080/claims/1001/summarize | jq ."
echo ""

echo "14. CloudWatch Log Groups"
echo "   aws logs describe-log-groups --log-group-name-prefix /aws/ --region us-east-1"
echo "   OR: AWS Console → CloudWatch → Log groups"
echo ""

echo "15. Logs Insights Queries"
echo "   AWS Console → CloudWatch → Logs Insights"
echo "   Show: observability/logs-insights-queries.md file"
echo ""

echo "16. Application Logs in CloudWatch"
echo "   AWS Console → CloudWatch → Log groups → /aws/containerinsights/introspect-dpn-eks/application"
echo ""

echo "17. Inspector Note"
echo "   Show: infra/modules/security/main.tf (commented Inspector code)"
echo ""

echo "18. Security Hub Note"
echo "   Show: infra/modules/security/main.tf (commented Security Hub code)"
echo ""

echo "19. IRSA Configuration"
echo "   kubectl describe sa sample-service-sample-service -n app"
echo "   kubectl exec <pod-name> -n app -- env | grep AWS"
echo ""

echo "20. CodeBuild Configuration"
echo "   Show: pipelines/buildspec.yml file"
echo ""

echo "21. GitHub Actions"
echo "   Show: .github/workflows/complete-cicd.yml file"
echo "   OR: GitHub → Actions tab"
echo ""

echo "22. Claims Data"
echo "   cat mocks/claims.json | jq ."
echo ""

echo "23. Notes Data"
echo "   cat mocks/notes.json | jq ."
echo ""

echo "24. Repository Structure"
echo "   tree -L 2 -I '.git|.terraform|node_modules'"
echo "   OR: ls -la"
echo ""

echo "25. GenAI Prompts"
echo "   Show: PROJECT_README.md (GenAI Prompts section)"
echo ""

echo "26. Terraform Modules"
echo "   ls -la infra/modules/"
echo ""

echo "27. Terraform Outputs"
echo "   cd infra/envs/dev && terraform output"
echo ""

echo "28. Cost Estimate"
echo "   Show: ARCHITECTURE.md (Cost Breakdown section)"
echo ""

echo "29. Test Results"
echo "   ./test-api.sh http://localhost:8080"
echo ""

echo "=== End of Screenshot Guide ==="
