data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Pod execution role for Fargate
data "aws_iam_policy_document" "eks_pod_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate_pod_exec" {
  name               = "${var.cluster_name}-fargate-pod-exec"
  assume_role_policy = data.aws_iam_policy_document.eks_pod_assume_role.json
}

resource "aws_iam_role_policy_attachment" "fargate_exec_attach" {
  role       = aws_iam_role.fargate_pod_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  # Prevent transient provider default changes from forcing a costly replacement by
  # ignoring changes to the bootstrap_self_managed_addons attribute which can
  # differ across provider versions.
  lifecycle {
    ignore_changes = [bootstrap_self_managed_addons]
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
}

resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "${var.cluster_name}-default"
  pod_execution_role_arn = aws_iam_role.fargate_pod_exec.arn
  subnet_ids             = var.subnet_ids

  selector {
    namespace = "default"
  }

  # Ensure core system pods (kube-system) are scheduled on Fargate
  selector {
    namespace = "kube-system"
  }
}
