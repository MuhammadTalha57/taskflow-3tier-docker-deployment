output "app_url" {
  description = "Open this in a browser - the running application."
  value       = "http://${aws_lb.public.dns_name}"
}

output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnets" {
  value = {
    public = aws_subnet.public[*].id
    web    = aws_subnet.web[*].id
    app    = aws_subnet.app[*].id
    db     = aws_subnet.db[*].id
  }
}

output "internal_alb_dns" {
  value = aws_lb.internal.dns_name
}

output "ecr_registry" {
  value = local.ecr_registry
}

output "ecr_repositories" {
  value = { for k, r in aws_ecr_repository.repo : k => r.repository_url }
}

output "rds_endpoint" {
  description = "Private DNS name - resolvable/reachable only from inside the VPC."
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "image_tag_parameter" {
  value = aws_ssm_parameter.image_tag.name
}

output "asg_names" {
  value = { web = local.asg_web_name, app = local.asg_app_name }
}

output "cloudwatch_dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.main.dashboard_name}"
}

# ---- values to paste into GitHub -> Settings -> Secrets and variables -> Actions ----
output "github_actions_variables" {
  description = "Create these as repository VARIABLES (not secrets - none of them is sensitive)."
  value = {
    AWS_REGION      = var.aws_region
    AWS_ROLE_ARN    = aws_iam_role.github_actions.arn
    ECR_REGISTRY    = local.ecr_registry
    IMAGE_TAG_PARAM = aws_ssm_parameter.image_tag.name
    WEB_ASG_NAME    = local.asg_web_name
    APP_ASG_NAME    = local.asg_app_name
    APP_URL         = "http://${aws_lb.public.dns_name}"
  }
}
