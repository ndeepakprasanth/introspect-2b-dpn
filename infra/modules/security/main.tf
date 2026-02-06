# Security Hub and Inspector (optional - requires permissions)
# Commented out due to lab permission restrictions
# Uncomment if you have inspector2:Enable and securityhub:EnableSecurityHub permissions

# resource "aws_inspector2_enabler" "this" {
#   account_ids    = [data.aws_caller_identity.current.account_id]
#   resource_types = ["ECR", "EC2"]
# }

# resource "aws_securityhub_account" "this" {}

# resource "aws_securityhub_standards_subscription" "cis" {
#   standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
#   depends_on    = [aws_securityhub_account.this]
# }

data "aws_caller_identity" "current" {}
