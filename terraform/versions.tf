terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


provider "aws" {
   assume_role {
    role_arn     = "arn:aws:iam::471727841202:role/aiengineer-role"
    session_name = "TerraformSession"
 }
  alias  = "us_east_1"
  region = "us-east-1"
}
