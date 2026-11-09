data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Latest Amazon Linux 2023 AMI, resolved from the public AWS SSM parameter
# (no hardcoded, region-specific AMI IDs).
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name = var.project
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # One /24 per subnet, one subnet per AZ per tier:
  #   public 10.0.0.0/24, 10.0.1.0/24   | web 10.0.10.0/24, 10.0.11.0/24
  #   app    10.0.20.0/24, 10.0.21.0/24 | db  10.0.30.0/24, 10.0.31.0/24
  public_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  web_cidrs    = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 10 + i)]
  app_cidrs    = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 20 + i)]
  db_cidrs     = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 30 + i)]

  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}
