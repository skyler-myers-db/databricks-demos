terraform {
  required_version = ">= 1.13.4"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.94.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.17.0"
    }
  }
}
