terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State is kept locally by default (terraform.tfstate, gitignored).
  # For team use, switch to a remote backend, e.g.:
  # backend "s3" {
  #   bucket       = "<your-state-bucket>"
  #   key          = "taskflow/terraform.tfstate"
  #   region       = "ap-south-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}

provider "aws" {
  region = var.aws_region

  # Every resource gets these tags -> easy cost tracking and cleanup.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Course    = "SE-490-CEA"
    }
  }
}
