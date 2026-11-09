# Security groups form a CHAIN — each tier only accepts traffic from the
# security group directly in front of it (SG-to-SG references, not CIDRs):
#
#   Internet --80--> public ALB --8080--> web EC2 --80--> internal ALB --4000--> app EC2 --5432--> RDS
#
# Egress is restricted too: instances may only open HTTPS (443) to the outside
# (ECR, SSM, CloudWatch, Secrets Manager, OS packages - all via NAT) plus the
# single next hop in the chain. No SSH (port 22) anywhere: shell access is via
# AWS Systems Manager Session Manager, which is IAM-authenticated and audited.

resource "aws_security_group" "public_alb" {
  name        = "${local.name}-public-alb-sg"
  description = "Public ALB: HTTP from the internet, forwards only to web tier"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-public-alb-sg" }
}

resource "aws_security_group" "web" {
  name        = "${local.name}-web-sg"
  description = "Web tier (nginx container): only reachable from public ALB"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-web-sg" }
}

resource "aws_security_group" "internal_alb" {
  name        = "${local.name}-internal-alb-sg"
  description = "Internal ALB: only reachable from web tier, forwards only to app tier"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-internal-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "App tier (Node/Express container): only reachable from internal ALB"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "RDS PostgreSQL: only reachable from app tier on 5432"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-db-sg" }
}

# ------------------------------------------------------------ public ALB ----
resource "aws_vpc_security_group_ingress_rule" "public_alb_http" {
  security_group_id = aws_security_group.public_alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "public_alb_to_web" {
  security_group_id            = aws_security_group.public_alb.id
  description                  = "Forward to web tier containers"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

# --------------------------------------------------------------- web tier ----
resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "nginx 8080 from public ALB only"
  referenced_security_group_id = aws_security_group.public_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "web_https_out" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS out via NAT (ECR, SSM, CloudWatch, packages)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "web_to_internal_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "Proxy /api to internal ALB"
  referenced_security_group_id = aws_security_group.internal_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# ---------------------------------------------------------- internal ALB ----
resource "aws_vpc_security_group_ingress_rule" "internal_alb_from_web" {
  security_group_id            = aws_security_group.internal_alb.id
  description                  = "HTTP from web tier only"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "internal_alb_to_app" {
  security_group_id            = aws_security_group.internal_alb.id
  description                  = "Forward to app tier containers"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 4000
  to_port                      = 4000
}

# --------------------------------------------------------------- app tier ----
resource "aws_vpc_security_group_ingress_rule" "app_from_internal_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Express 4000 from internal ALB only"
  referenced_security_group_id = aws_security_group.internal_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 4000
  to_port                      = 4000
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS out via NAT (ECR, SSM, Secrets Manager, CloudWatch)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL to RDS"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# --------------------------------------------------------------- database ----
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from app tier only"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
# (no egress rules on the DB security group: RDS never initiates connections)
