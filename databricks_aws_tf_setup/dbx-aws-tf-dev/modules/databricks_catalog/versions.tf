terraform {
  required_version = ">= 1.13.4"

  required_providers {
    databricks = {
      source                = "databricks/databricks"
      version               = "~> 1.95.0"
      configuration_aliases = [databricks.workspace]
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}
