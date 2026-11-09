# ===================================================== EC2 instance roles ====
# Each tier gets its OWN role with only what that tier needs (least privilege).
# No access keys exist on any instance: credentials come from the instance
# profile via IMDSv2 and rotate automatically.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${local.name}-web-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-app-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Session Manager shell access (replaces SSH + bastion host) and ECR pull (read-only).
resource "aws_iam_role_policy_attachment" "ssm" {
  for_each   = { web = aws_iam_role.web.name, app = aws_iam_role.app.name }
  role       = each.value
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  for_each   = { web = aws_iam_role.web.name, app = aws_iam_role.app.name }
  role       = each.value
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Read the deployed image tag + write container logs to ITS OWN log group.
data "aws_iam_policy_document" "tier" {
  for_each = { web = aws_cloudwatch_log_group.web.arn, app = aws_cloudwatch_log_group.app.arn }

  statement {
    sid       = "ReadImageTag"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.image_tag.arn]
  }

  statement {
    sid       = "ShipContainerLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = [each.value, "${each.value}:*"]
  }
}

resource "aws_iam_role_policy" "web" {
  name   = "${local.name}-web-policy"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.tier["web"].json
}

resource "aws_iam_role_policy" "app" {
  name   = "${local.name}-app-policy"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.tier["app"].json
}

# ONLY the app tier may read the DB secret — the web tier cannot.
data "aws_iam_policy_document" "app_db_secret" {
  statement {
    sid       = "ReadDbSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db.arn]
  }
}

resource "aws_iam_role_policy" "app_db_secret" {
  name   = "${local.name}-app-db-secret"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_db_secret.json
}

resource "aws_iam_instance_profile" "web" {
  name = "${local.name}-web-profile"
  role = aws_iam_role.web.name
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app-profile"
  role = aws_iam_role.app.name
}

# ============================================ GitHub Actions (OIDC) role ====
# GitHub Actions authenticates to AWS with a short-lived OIDC token — there
# are NO long-lived AWS access keys stored in GitHub. The trust policy only
# accepts tokens issued for this exact repository AND branch.

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # GitHub puts the repo identity in the token "sub" claim in one of two formats:
  #   classic   : repo:<owner>/<repo>
  #   immutable : repo:<owner>@<owner_id>/<repo>@<repo_id>   (newer repos; check with
  #               gh api repos/<owner>/<repo>/actions/oidc/customization/sub)
  # and the suffix depends on the job:
  #   :ref:refs/heads/<branch>   for jobs without an environment (build-and-push)
  #   :environment:<name>        for jobs that use a GitHub environment (deploy)
  github_sub_prefixes = compact(["repo:${var.github_repository}", var.github_immutable_sub_prefix])
  github_allowed_subs = flatten([
    for p in local.github_sub_prefixes : [
      "${p}:ref:refs/heads/${var.github_branch}",
      "${p}:environment:${var.github_environment}",
    ]
  ])
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_allowed_subs # exact matches only, no wildcards
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${local.name}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action does not support resource-level permissions
  }

  statement {
    sid = "EcrPushOnlyOurRepos"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:DescribeImages",
    ]
    resources = [for r in aws_ecr_repository.repo : r.arn]
  }

  statement {
    sid       = "SetDeployedImageTag"
    actions   = ["ssm:PutParameter", "ssm:GetParameter"]
    resources = [aws_ssm_parameter.image_tag.arn]
  }

  statement {
    sid       = "RollOutOurAsgsOnly"
    actions   = ["autoscaling:StartInstanceRefresh"]
    resources = [for asg in aws_autoscaling_group.tier : asg.arn]
  }

  statement {
    sid = "ReadOnlyDescribe"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeInstanceRefreshes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
    ]
    resources = ["*"] # Describe* calls do not support resource-level permissions
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${local.name}-github-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
