terraform {
  required_version = ">= 1.13.4"

  # Backend configuration will be added after terraform_backend module is deployed
  # See module.terraform_backend output for exact configuration to add here

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.95.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.12.0"
    }
  }
}
