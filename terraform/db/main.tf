terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State isolated from the Kubernetes stack: the database must never be
  # destroyed by a cluster rebuild.
  backend "s3" {
    bucket = "auto-repair-terraform-state"
    key    = "db/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "auto-repair-shop"
      Environment = var.environment
      Stack       = "database"
      ManagedBy   = "terraform"
    }
  }
}

# Network created by the Kubernetes stack, consumed here as a read-only input.
data "terraform_remote_state" "k8s" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "k8s/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}
