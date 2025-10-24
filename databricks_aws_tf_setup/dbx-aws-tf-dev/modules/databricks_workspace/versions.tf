# ============================================================================
# Terraform and Provider Version Constraints
# ============================================================================
# Module: databricks_workspace
# Purpose: Databricks workspace creation on AWS
# ============================================================================

terraform {
  required_version = ">= 1.13.4"

  required_providers {
    databricks = {
      source                = "databricks/databricks"
      version               = "~> 1.94.0"
      configuration_aliases = [databricks.mws]
    }
  }
}
