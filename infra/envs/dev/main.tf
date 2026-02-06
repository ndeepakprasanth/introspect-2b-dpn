module "vpc" {
  source = "../../modules/vpc"
  name   = "introspect-dev-vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source       = "../../modules/eks"
  cluster_name = "introspect-dpn-eks"
  # Use private subnets for EKS control plane / Fargate where available
  subnet_ids = module.vpc.private_subnet_ids
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "introspect-sample-service"
}

module "s3_notes" {
  source = "../../modules/s3"
  bucket = "introspect-sample-service-notes-${random_id.suffix.hex}"
  tags = {
    Environment = "dev"
  }
}

module "dynamodb_claims" {
  source     = "../../modules/dynamodb"
  table_name = "introspect-claims"
  tags = {
    Environment = "dev"
  }
}

module "pipeline" {
  source          = "../../modules/pipeline"
  project_name    = "introspect-sample-build"
  pipeline_name   = "introspect-sample-pipeline"
  repository      = "ndeepakprasanth/introspect-2b-dpn"
  branch          = "main"
  connection_arn  = var.code_connection_arn
  artifact_bucket = aws_s3_bucket.pipeline_artifacts.bucket
  buildspec       = "${path.root}/../../pipelines/buildspec.yml"
  region          = var.region
  tags = {
    Environment = "dev"
  }
}

resource "random_id" "suffix" {
  byte_length = 2
}

module "node_group" {
  source = "../../modules/node_group"
  # prefer exported cluster output if present
  cluster_name = module.eks.cluster_name != null ? module.eks.cluster_name : "introspect-dpn-eks"
  # use the same subnets used by the cluster
  subnet_ids      = module.vpc.public_subnet_ids
  node_group_name = "demo-node-group"
  desired_size    = 1
  min_size        = 1
  max_size        = 2
  instance_types  = ["t3.small"]
}

# pipeline artifact bucket used by CodePipeline (create if not present)
resource "random_id" "artifacts" {
  byte_length = 2
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = var.pipeline_artifact_bucket != "" ? var.pipeline_artifact_bucket : "introspect-pipeline-artifacts-${data.aws_caller_identity.current.account_id}-${random_id.artifacts.hex}"
  acl    = "private"
  versioning {
    enabled = true
  }
  tags = {
    Environment = "dev"
  }
}

# IRSA for Bedrock access
module "bedrock_iam" {
  source            = "../../modules/iam"
  sa_namespace      = "default"
  sa_name           = "sample-service"
  oidc_provider_url = module.eks.oidc_provider_url
  oidc_provider_arn = module.eks.oidc_provider_arn
  tags = {
    Environment = "dev"
  }
  depends_on = [module.eks]
}

# Observability
module "observability" {
  source       = "../../modules/observability"
  api_name     = "introspect-claims-api"
  cluster_name = module.eks.cluster_name != null ? module.eks.cluster_name : "introspect-dpn-eks"
  region       = var.region
}

# Security Hub and Inspector
module "security" {
  source = "../../modules/security"
  region = var.region
}

# NLB for API Gateway integration
resource "aws_security_group" "nlb" {
  name   = "introspect-nlb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "nlb" {
  source     = "../../modules/nlb"
  nlb_name   = "introspect-nlb"
  subnet_ids = module.vpc.private_subnet_ids
  vpc_id     = module.vpc.vpc_id
}

# API Gateway
module "api_gateway" {
  source                   = "../../modules/api-gateway"
  api_name                 = "introspect-claims-api"
  security_group_ids       = [aws_security_group.nlb.id]
  subnet_ids               = module.vpc.private_subnet_ids
  nlb_listener_arn         = module.nlb.listener_arn
  cloudwatch_log_group_arn = module.observability.api_log_group_arn
}
