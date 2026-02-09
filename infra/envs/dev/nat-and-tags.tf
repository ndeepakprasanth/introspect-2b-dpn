#############################################
# NAT gateway for Fargate in private subnets
#############################################

# Allocate an Elastic IP for the NAT GW
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "introspect-dev-nat-eip"
  }
}

# Place the NAT GW in the first public subnet
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = module.vpc.public_subnet_ids[0]
  tags = {
    Name = "introspect-dev-nat"
  }
  depends_on = [module.vpc]
}

# Look up the existing *private* route table created by the VPC module
# The module tags it as Name = "introspect-dev-vpc-private-rt"
data "aws_route_table" "private" {
  vpc_id = module.vpc.vpc_id
  filter {
    name   = "tag:Name"
    values = ["introspect-dev-vpc-private-rt"]
  }
}

# Add the default route to NAT in the EXISTING private RT (no re-association)
resource "aws_route" "private_default_via_nat" {
  route_table_id         = data.aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

#############################################
# EKS subnet discovery tags (private)
#############################################

# Tag each private subnet with the cluster discovery tag
resource "aws_ec2_tag" "private_cluster_tag" {
  count       = length(module.vpc.private_subnet_ids)
  resource_id = module.vpc.private_subnet_ids[count.index]
  key         = "kubernetes.io/cluster/${module.eks.cluster_name}"
  value       = "shared"
}

# Tag each private subnet as internal-elb capable
resource "aws_ec2_tag" "private_internal_elb" {
  count       = length(module.vpc.private_subnet_ids)
  resource_id = module.vpc.private_subnet_ids[count.index]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
