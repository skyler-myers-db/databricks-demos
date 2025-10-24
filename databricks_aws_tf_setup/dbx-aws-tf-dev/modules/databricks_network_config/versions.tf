/**
 * Databricks Network Configuration Module - Version Constraints
 *
 * Uses Databricks provider for account-level configuration
 */

terraform {
  required_version = ">= 1.13.4"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.95.0"
    }
  }
}
