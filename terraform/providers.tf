provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "cloud-resume-challenge"
      ManagedBy = "Terraform"
      Owner     = "Jinghan Fu"
    }
  }
}