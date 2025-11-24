terraform {
  required_version = ">= 1.0"

  cloud {
    organization = "mahen-arch"

    workspaces {
      name = "ask-about-mahen-llm"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
