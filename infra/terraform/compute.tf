# Each tier = Launch Template (what an instance looks like) + Auto Scaling
# Group (how many, where) + target-tracking policy (when to add/remove).
# Instances are stateless and disposable: everything they need is pulled at
# boot (image from ECR, tag from SSM, DB secret from Secrets Manager).

locals {
  tiers = {
    web = {
      subnets      = aws_subnet.web[*].id
      sg           = aws_security_group.web.id
      profile      = aws_iam_instance_profile.web.name
      target_group = aws_lb_target_group.web.arn
      size         = var.web_asg
      user_data = templatefile("${path.module}/templates/web-user-data.sh.tftpl", {
        region           = var.aws_region
        ecr_registry     = local.ecr_registry
        image_repo       = aws_ecr_repository.repo["frontend"].name
        image_tag_param  = aws_ssm_parameter.image_tag.name
        internal_alb_dns = aws_lb.internal.dns_name
        log_group        = aws_cloudwatch_log_group.web.name
      })
    }
    app = {
      subnets      = aws_subnet.app[*].id
      sg           = aws_security_group.app.id
      profile      = aws_iam_instance_profile.app.name
      target_group = aws_lb_target_group.app.arn
      size         = var.app_asg
      user_data = templatefile("${path.module}/templates/app-user-data.sh.tftpl", {
        region          = var.aws_region
        ecr_registry    = local.ecr_registry
        image_repo      = aws_ecr_repository.repo["backend"].name
        image_tag_param = aws_ssm_parameter.image_tag.name
        db_secret_arn   = aws_secretsmanager_secret.db.arn
        log_group       = aws_cloudwatch_log_group.app.name
      })
    }
  }
}

resource "aws_launch_template" "tier" {
  for_each      = local.tiers
  name_prefix   = "${local.name}-${each.key}-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type
  user_data     = base64encode(each.value.user_data)

  vpc_security_group_ids = [each.value.sg]

  iam_instance_profile {
    name = each.value.profile
  }

  # IMDSv2 only; hop limit 1 means processes inside Docker containers cannot
  # reach the metadata service and steal the instance role credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-${each.key}", Tier = each.key }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${local.name}-${each.key}-root", Tier = each.key }
  }
}

resource "aws_autoscaling_group" "tier" {
  for_each            = local.tiers
  name                = "${local.name}-${each.key}-asg"
  vpc_zone_identifier = each.value.subnets # spread across AZs
  min_size            = each.value.size.min
  max_size            = each.value.size.max
  desired_capacity    = each.value.size.desired
  target_group_arns   = [each.value.target_group]

  # Replace instances that the load balancer reports unhealthy, not only
  # instances whose hardware fails.
  health_check_type         = "ELB"
  health_check_grace_period = 240
  default_instance_warmup   = 120

  launch_template {
    id      = aws_launch_template.tier[each.key].id
    version = aws_launch_template.tier[each.key].latest_version
  }

  # Zero-downtime rolling replacement (used by Terraform when the launch
  # template changes, and by the CI/CD pipeline on every release).
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  enabled_metrics = ["GroupInServiceInstances", "GroupDesiredCapacity", "GroupMinSize", "GroupMaxSize"]

  tag {
    key                 = "Name"
    value               = "${local.name}-${each.key}"
    propagate_at_launch = true
  }

  lifecycle {
    # Auto scaling changes desired_capacity at runtime; don't fight it.
    ignore_changes = [desired_capacity]
  }

  # Make sure the DB secret exists before app instances try to read it.
  depends_on = [aws_secretsmanager_secret_version.db, aws_nat_gateway.main, aws_route_table_association.web, aws_route_table_association.app]
}

# Elasticity: keep average CPU around the target by adding/removing instances.
resource "aws_autoscaling_policy" "cpu" {
  for_each               = aws_autoscaling_group.tier
  name                   = "${local.name}-${each.key}-cpu-target"
  autoscaling_group_name = each.value.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_percent
  }
}

# Short aliases used by iam.tf / outputs.tf
locals {
  asg_web_name = aws_autoscaling_group.tier["web"].name
  asg_app_name = aws_autoscaling_group.tier["app"].name
}
