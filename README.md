# Introspect-2B — Minimal Terraform scaffold (single env)

This project contains a minimal Terraform scaffold for a GenAI-enabled cloud-native sample (Level 2 course).

Key points:
- Single working environment: `infra/envs/dev`
- Default EKS cluster name: `introspect-dpn-eks`
- One-step bootstrap script at repository root: `bootstrap-infra.sh`

Quick start:

1. Ensure `aws` CLI and `terraform` are installed and AWS credentials are configured.
2. Make the script executable: `chmod +x bootstrap-infra.sh`
3. Run it interactively: `./bootstrap-infra.sh`
   - Or non-interactively: `TF_STATE_BUCKET=my-bucket TF_STATE_KEY=instrospect2/dev/terraform.tfstate AWS_REGION=us-east-1 ./bootstrap-infra.sh`

One-shot demo: use `./run-demo.sh` to create a small managed node group, build & push the demo image to ECR, deploy the Helm chart and wait for pods to become ready. The script accepts environment variables: `AWS_PROFILE`, `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_KEY`, `DYNAMODB_TABLE`, `EKS_CLUSTER_NAME`, `AWS_ACCOUNT_ID`, and `IMAGE_TAG`. This is useful because the lab environment resets frequently — re-run `./run-demo.sh` to bring demo back up quickly.

Notes:
- The script will create S3 bucket and DynamoDB table if they don't exist, then initialize and apply Terraform in `infra/envs/dev`.
- CI: a GitHub Actions workflow exists at `.github/workflows/terraform.yml` to run plans on PRs and applies on `main` (requires secrets for S3 backend).

