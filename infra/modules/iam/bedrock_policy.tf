// IAM resources for allowing a Kubernetes service account to invoke Bedrock models (IRSA)

data "aws_iam_policy_document" "bedrock_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"

      values = ["system:serviceaccount:${var.sa_namespace}:${var.sa_name}"]
    }
  }
}

resource "aws_iam_role" "bedrock_sa_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.bedrock_assume_role.json
  tags               = var.tags
}

// Policy that allows invoking Bedrock models. For simplicity this uses a broad resource '*'.
// You can scope this tighter by using model ARNs when available.
data "aws_iam_policy_document" "bedrock_policy_doc" {
  statement {
    sid     = "AllowBedrockInvoke"
    effect  = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:GetModel",
      "bedrock:DescribeModel"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  name        = var.policy_name
  description = "Allow invocation of Amazon Bedrock models for the sample service"
  policy      = data.aws_iam_policy_document.bedrock_policy_doc.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_bedrock_policy" {
  role       = aws_iam_role.bedrock_sa_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}
