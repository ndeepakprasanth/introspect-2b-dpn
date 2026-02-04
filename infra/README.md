# Infra (minimal dev scaffold)

This repo contains a minimal Terraform scaffold for local development and testing.

Structure created:
- `infra/global` — local backend + provider config
- `infra/modules/vpc` — minimal VPC + public subnets
- `infra/modules/eks` — minimal EKS cluster (Fargate profile) + IAM roles
- `infra/modules/ecr` — simple ECR repository
- `infra/envs/dev` — root module wiring the modules for a dev environment

Quick start (local testing):

1. cd infra/global
2. terraform init
3. cd ../envs/dev
4. terraform init
5. terraform apply -auto-approve

Notes:
- `backend` is intentionally set to `local` to keep things simple. Switch to an S3 backend for shared state.
- This is a minimal, opinionated setup meant for rapid iteration. We can add more features (private subnets, NAT gateways, CI-managed remote state, etc.) when you are ready.
