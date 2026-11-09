# --------------------------------------------- Public (internet-facing) ALB ----
resource "aws_lb" "public" {
  name                       = "${local.name}-public-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.public_alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
  tags                       = { Name = "${local.name}-public-alb" }
}

resource "aws_lb_target_group" "web" {
  name                 = "${local.name}-web-tg"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ------------------------------------------- Internal ALB (web -> app only) ----
# Gives the web tier ONE stable DNS name for the app tier and load-balances
# across however many app instances the Auto Scaling Group is running.
resource "aws_lb" "internal" {
  name                       = "${local.name}-internal-alb"
  load_balancer_type         = "application"
  internal                   = true
  security_groups            = [aws_security_group.internal_alb.id]
  subnets                    = aws_subnet.app[*].id
  drop_invalid_header_fields = true
  tags                       = { Name = "${local.name}-internal-alb" }
}

resource "aws_lb_target_group" "app" {
  name                 = "${local.name}-app-tg"
  port                 = 4000
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "instance"
  deregistration_delay = 30

  # /health runs "SELECT 1" against RDS, so an instance is only "healthy"
  # when it can actually serve requests end-to-end.
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
