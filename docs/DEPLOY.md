CI/CD and Deployment notes

Secrets required in GitHub repo for the CI/CD workflow (.github/workflows/ci-cd.yml):
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_REGION (e.g., us-east-1)
- AWS_ACCOUNT_ID (your AWS account id)
- EKS_CLUSTER_NAME (introspect-dpn-eks)

Steps to enable CI/CD:
1. Ensure `infra/state` Terraform is applied to create the S3 bucket and DynamoDB (or use the existing bucket you created earlier).
   cd infra/state && terraform init && terraform apply -var "bucket_name=instrospect2b-dpn-state-bucket" -auto-approve
2. Set GitHub secrets listed above for the repository.
3. Push to `main` branch or trigger the workflow using `workflow_dispatch`.

Local deployment:
1. Build and push image locally to ECR (or let the CI do it).
2. Update kubeconfig and run `helm upgrade --install sample-service app/services/sample-service --set image.repository=<ECR>/<repo> --set image.tag=latest`.
