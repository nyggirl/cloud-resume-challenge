terraform {
  required_version = ">= 1.15.0"

  backend "s3" {
    bucket       = "jinghanfu-cloud-resume-terraform-state"
    key          = "cloud-resume/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}