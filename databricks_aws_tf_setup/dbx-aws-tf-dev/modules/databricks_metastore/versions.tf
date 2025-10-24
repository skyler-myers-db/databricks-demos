/**
 * Databricks Metastore Module - Version Constraints
 *
 * Uses Databricks provider for Unity Catalog metastore creation
 */

terraform {
  required_version = ">= 1.13.4"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.94.0"
    }
  }
}
