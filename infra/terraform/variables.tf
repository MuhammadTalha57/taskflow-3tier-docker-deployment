variable "project" {
  description = "Name prefix for all resources."
  type        = string
  default     = "taskflow"
}

variable "aws_region" {
  description = "AWS region. ap-south-1 (Mumbai) is the closest region to Pakistan, so it has the lowest latency for our users."
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (65,536 addresses)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets/instances over (>= 2 is required by ALB and the RDS subnet group)."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "true = one NAT Gateway (cheaper, single-AZ dependency); false = one NAT per AZ (highly available)."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type for web and app container hosts."
  type        = string
  default     = "t3.micro"
}

variable "web_asg" {
  description = "Web tier Auto Scaling Group sizing."
  type        = object({ min = number, desired = number, max = number })
  default     = { min = 2, desired = 2, max = 4 }
}

variable "app_asg" {
  description = "App tier Auto Scaling Group sizing."
  type        = object({ min = number, desired = number, max = number })
  default     = { min = 2, desired = 2, max = 4 }
}

variable "cpu_target_percent" {
  description = "Target average CPU utilisation for target-tracking auto scaling."
  type        = number
  default     = 50
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL major version for RDS (matches postgres:16 used locally)."
  type        = string
  default     = "16"
}

variable "db_name" {
  type    = string
  default = "taskflow"
}

variable "db_username" {
  type    = string
  default = "taskflow"
}

variable "db_multi_az" {
  description = "Synchronous standby in a second AZ with automatic failover (doubles DB cost)."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days. Free-tier accounts may reject values greater than 1."
  type        = number
  default     = 1
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as owner/name."
  type        = string
  default     = "MuhammadTalha57/taskflow-3tier-docker-deployment"
}

variable "github_branch" {
  description = "Only workflow runs on this branch can assume the deploy role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Set false if the AWS account already has the token.actions.githubusercontent.com OIDC provider."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  type    = number
  default = 7
}
