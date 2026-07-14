terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project   = "cloud-resume-challenge"
      Owner     = "Jinghan Fu"
      ManagedBy = "Terraform"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "jinghanfu-cloud-resume-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:nyggirl/cloud-resume-challenge:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name = "cloud-resume-github-actions-role"

  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC."
  value       = aws_iam_role.github_actions.arn
}

data "aws_iam_policy_document" "github_actions_state_access" {
  statement {
    sid    = "ListTerraformStateBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.terraform_state.arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = [
        "cloud-resume/*"
      ]
    }
  }

  statement {
    sid    = "ManageTerraformStateObject"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.terraform_state.arn}/cloud-resume/terraform.tfstate",
      "${aws_s3_bucket.terraform_state.arn}/cloud-resume/terraform.tfstate.tflock"
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_state_access" {
  name = "cloud-resume-github-actions-state-access"
  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_actions_state_access.json
}

data "aws_iam_policy_document" "github_actions_deployment" {
  statement {
    sid    = "ManageWebsiteBucket"
    effect = "Allow"

    actions = [
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:GetBucketWebsite",
      "s3:PutBucketWebsite",
      "s3:DeleteBucketWebsite",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketVersioning",
      "s3:GetAccelerateConfiguration"
    ]

    resources = [
      "arn:aws:s3:::jinghanfu-cloud-resume"
    ]
  }

  statement {
    sid    = "ManageWebsiteObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging"
    ]

    resources = [
      "arn:aws:s3:::jinghanfu-cloud-resume/*"
    ]
  }

  statement {
    sid    = "ManageCloudFront"
    effect = "Allow"

    actions = [
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:CreateDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:CreateInvalidation",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ManageVisitorCounterTable"
    effect = "Allow"

    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:CreateTable",
      "dynamodb:UpdateTable",
      "dynamodb:DeleteTable",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource"
    ]

    resources = [
      "arn:aws:dynamodb:us-east-2:943378954479:table/cloud-resume-visitor-counter"
    ]
  }

  statement {
    sid    = "ManageVisitorCounterLambda"
    effect = "Allow"

    actions = [
      "lambda:GetFunction",
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListVersionsByFunction"
    ]

    resources = [
      "arn:aws:lambda:us-east-2:943378954479:function:cloud-resume-visitor-counter"
    ]
  }

  statement {
    sid    = "ManageVisitorCounterApi"
    effect = "Allow"

    actions = [
      "apigateway:*"
    ]

    resources = [
      "arn:aws:apigateway:us-east-2::/apis/*"
    ]
  }

  statement {
    sid    = "ManageLambdaIamRole"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::943378954479:role/cloud-resume-lambda-execution-role"
    ]
  }

  statement {
    sid    = "ReadAccountMetadata"
    effect = "Allow"

    actions = [
      "sts:GetCallerIdentity"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deployment" {
  name = "cloud-resume-github-actions-deployment"
  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_actions_deployment.json
}

