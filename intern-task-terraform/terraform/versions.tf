terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Allows plan-only validation without real AWS credentials.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  default_tags {
    tags = {
      Project   = "intern-task"
      ManagedBy = "terraform"
    }
  }
}