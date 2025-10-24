/**
 * Databricks IAM Policy Module - Version Constraints
 *
 * Maintains consistency with other modules in the project
 */

terraform {
  required_version = ">= 1.13.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
  }
}
