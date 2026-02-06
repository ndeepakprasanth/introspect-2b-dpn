# Minimal CodeBuild and CodePipeline skeleton.
# Note: This module assumes a CodeStar connection ARN for GitHub as an input variable.

resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "${var.project_name}-codebuild-policy"
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "s3:GetObject",
      "s3:PutObject",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "sts:AssumeRole",
      "eks:DescribeCluster",
      "ssm:GetParameter"
    ]
    resources = ["*"]
  }
}

resource "aws_codebuild_project" "this" {
  name         = var.project_name
  service_role = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec
  }
  tags = var.tags
}

# CodePipeline skeleton - requires a CodeStar connection (connection_arn variable)
resource "aws_codepipeline" "this" {
  name = var.pipeline_name

  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = var.artifact_bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.connection_arn
        FullRepositoryId = var.repository
        BranchName       = var.branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  tags = var.tags
}

# Roles for CodePipeline
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.pipeline_name}-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "${var.pipeline_name}-policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:BatchGetProjects",
      "iam:PassRole",
      "ecr:*"
    ]
    resources = ["*"]
  }
}
