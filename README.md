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

Notes:
- The script will create S3 bucket and DynamoDB table if they don't exist, then initialize and apply Terraform in `infra/envs/dev`.
- CI: a GitHub Actions workflow exists at `.github/workflows/terraform.yml` to run plans on PRs and applies on `main` (requires secrets for S3 backend).

