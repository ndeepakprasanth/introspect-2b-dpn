module "vpc" {
  source = "../../modules/vpc"
  name   = "introspect-dev-vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source       = "../../modules/eks"
  cluster_name = "introspect-dpn-eks"
  subnet_ids   = module.vpc.private_subnet_ids
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "introspect-sample-service"
}
