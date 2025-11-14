# ============================================================================
# JOB RUNNER SERVICE PRINCIPAL
# ============================================================================
# Purpose: Service principal for running Databricks jobs via Asset Bundles
# Scope: Account-level creation, workspace-level permissions (NO ADMIN)
# Use Case: Automated job execution, CI/CD pipelines, scheduled workloads
#
# PERMISSIONS:
# - CAN: Run jobs, access catalogs/schemas (via grants), read/write data
# - CANNOT: Create workspaces, manage users, modify account settings
#
# MANAGED BY: Databricks Asset Bundles (DABs) configuration
# ============================================================================

resource "databricks_service_principal" "job_runner" {
  provider                   = databricks
  display_name               = "${var.project_name}-${var.env}-${var.service_principal_name}"
  external_id                = "${var.project_name}-${var.env}-${var.service_principal_name}"
  allow_cluster_create       = true
  allow_instance_pool_create = false
  active                     = true
}

# ============================================================================
# OAUTH SECRET FOR AUTHENTICATION
# ============================================================================
# Generates OAuth M2M credentials for the service principal
# Used by Databricks Asset Bundles for authentication

resource "databricks_service_principal_secret" "job_runner" {
  provider             = databricks
  service_principal_id = databricks_service_principal.job_runner.id
}

# ============================================================================
# WORKSPACE ASSIGNMENT (USER ROLE - NOT ADMIN)
# ============================================================================
# Assigns the service principal to the workspace with USER permissions
# This allows it to run jobs but NOT perform administrative actions

resource "databricks_mws_permission_assignment" "job_runner_workspace" {
  provider     = databricks
  workspace_id = var.workspace_id
  principal_id = databricks_service_principal.job_runner.id
  permissions  = ["USER"]
}
