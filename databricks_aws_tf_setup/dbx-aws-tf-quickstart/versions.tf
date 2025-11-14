terraform {
  required_version = ">= 1.13.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21.0"
    }

    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.97.0"
    }
  }
}
