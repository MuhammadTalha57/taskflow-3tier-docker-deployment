# ------------------------------------------------- Container registry (ECR) ----
locals {
  ecr_repos = {
    frontend = "${local.name}-frontend"
    backend  = "${local.name}-backend"
  }
}

resource "aws_ecr_repository" "repo" {
  for_each             = local.ecr_repos
  name                 = each.value
  image_tag_mutability = "MUTABLE" # "latest" is moved on every release; sha-* tags are never overwritten
  force_delete         = true      # lets `terraform destroy` remove repos that still contain images

  image_scanning_configuration {
    scan_on_push = true # basic CVE scan of every pushed image
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keep storage (and cost) bounded: only the 10 most recent images are kept.
resource "aws_ecr_lifecycle_policy" "repo" {
  for_each   = aws_ecr_repository.repo
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# The image tag currently deployed. CI/CD writes the new git-SHA tag here and
# then triggers an ASG instance refresh; new instances read it at boot.
resource "aws_ssm_parameter" "image_tag" {
  name        = "/${local.name}/image-tag"
  description = "Docker image tag deployed to the web and app tiers"
  type        = "String"
  value       = "latest"

  lifecycle {
    ignore_changes = [value] # owned by the CI/CD pipeline after creation
  }
}
