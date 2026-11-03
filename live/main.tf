terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The state file location ("key") is different for every team.
  # CI passes it in: -backend-config="key=teams/<team>.tfstate"
  backend "s3" {
    bucket       = "acme-terraform-state"
    region       = "eu-west-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-1"
}

variable "team_name" {
  type = string
}

variable "cost_center" {
  type = string
}

variable "buckets" {
  type = list(object({
    name       = string
    visibility = string
  }))
}

module "team" {
  source = "../modules/team"

  prefix      = "acme"
  team_name   = var.team_name
  cost_center = var.cost_center
  buckets     = var.buckets
}

output "role_arn" {
  value = module.team.role_arn
}

output "bucket_names" {
  value = module.team.bucket_names
}