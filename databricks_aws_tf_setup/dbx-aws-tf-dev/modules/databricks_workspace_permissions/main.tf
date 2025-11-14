/**
 * Databricks Workspace Permissions Module
 *
 * Purpose:
 * Manages workspace-level admin assignments for SCIM-synced users and groups.
 * Does NOT manage users/groups themselves - those are managed by Google SCIM.
 *
 * Key Principles:
 * - Users/Groups: Managed by Google SCIM (source of truth)
 * - Workspace Assignments: Managed by Terraform (which users have access)
 * - Service Principals: Managed by Terraform (automation accounts)
 *
 * Use Cases:
 * - Assign specific users as workspace admins (e.g., skyler@entrada.ai)
 * - Assign groups to workspaces (e.g., data_engineers group)
 * - Consistent admin assignment across multiple workspaces
 *
 * IMPORTANT:
 * This module uses data sources to REFERENCE users/groups that already exist
 * via SCIM. It does NOT create them. This prevents conflicts with SCIM sync.
 *
 * Databricks Documentation:
 * https://docs.databricks.com/administration-guide/users-groups/users.html
 *
 * Cost: $0/month (permission assignments are free)
 */

# ============================================================================
# DATA SOURCE: SCIM-SYNCED USER
# ============================================================================
# References a user that was synced from Google via SCIM
# Does NOT manage the user - Google SCIM is the source of truth

data "databricks_user" "workspace_admin" {
  provider  = databricks
  user_name = var.admin_user_email

  # This data source will fail if user doesn't exist yet via SCIM
  # Ensure Google SCIM has synced the user before running Terraform
}

# ============================================================================
# DATA SOURCE: SCIM-SYNCED GROUP (DATA ENGINEERS)
# ============================================================================
# References the data_engineers group that was synced from Google via SCIM

data "databricks_group" "data_engineers" {
  count        = var.assign_data_engineers_group ? 1 : 0
  provider     = databricks
  display_name = var.data_engineers_group_name

  # This data source will fail if group doesn't exist yet via SCIM
  # Ensure Google SCIM has synced the group before running Terraform
}

# ============================================================================
# WORKSPACE ADMIN ASSIGNMENT (USER)
# ============================================================================
# Assigns a specific user as workspace admin
# User is managed by SCIM, but workspace assignment is managed by Terraform

resource "databricks_mws_permission_assignment" "user_admin" {
  provider     = databricks
  workspace_id = var.workspace_id
  principal_id = data.databricks_user.workspace_admin.id
  permissions  = ["ADMIN"]
}

# ============================================================================
# WORKSPACE USER ASSIGNMENT (GROUP)
# ============================================================================
# Assigns the data_engineers group to the workspace
# Group is managed by SCIM, but workspace assignment is managed by Terraform
# Permission level: USER (can create notebooks, clusters, jobs)

resource "databricks_mws_permission_assignment" "data_engineers_users" {
  count        = var.assign_data_engineers_group ? 1 : 0
  provider     = databricks
  workspace_id = var.workspace_id
  principal_id = data.databricks_group.data_engineers[0].id
  permissions  = ["USER"]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "admin_user_id" {
  description = "User ID of the workspace admin"
  value       = data.databricks_user.workspace_admin.id
}

output "admin_user_email" {
  description = "Email of the workspace admin"
  value       = data.databricks_user.workspace_admin.user_name
}

output "data_engineers_group_id" {
  description = "Group ID of data_engineers (null if not assigned)"
  value       = var.assign_data_engineers_group ? data.databricks_group.data_engineers[0].id : null
}

output "data_engineers_group_name" {
  description = "Display name of the data_engineers group"
  value       = var.assign_data_engineers_group ? data.databricks_group.data_engineers[0].display_name : null
}

output "workspace_assignments_summary" {
  description = "Summary of workspace permission assignments"
  value = {
    workspace_id = var.workspace_id
    admin_users  = [data.databricks_user.workspace_admin.user_name]
    user_groups  = var.assign_data_engineers_group ? [var.data_engineers_group_name] : []
  }
}

# ============================================================================
# CONFIGURATION NOTES
# ============================================================================
#
# GOOGLE SCIM SETUP REQUIREMENTS:
# --------------------------------
# Before using this module, ensure:
# 1. Google Workspace → Databricks SCIM is configured
# 2. User (skyler@entrada.ai) has been synced to Databricks
# 3. Group (data_engineers) has been synced to Databricks
# 4. Run initial sync and verify users/groups exist in Databricks UI
#
# TERRAFORM STATE MANAGEMENT:
# ---------------------------
# - User/group existence checked via data sources (read-only)
# - Workspace assignments managed by Terraform (create/update/delete)
# - Removing this module removes workspace access (users still exist)
# - SCIM sync continues independently of Terraform
#
# ADDING NEW USERS TO data_engineers GROUP:
# ------------------------------------------
# To add new users to the data_engineers group:
# 1. Add user to the group in Google Workspace
# 2. SCIM automatically syncs the change to Databricks
# 3. User automatically gets workspace access (via group assignment)
# 4. NO Terraform changes required!
#
# This is the power of SCIM + Terraform working together:
# - Google manages who is in the group (IdP source of truth)
# - Terraform manages which groups have access (infrastructure as code)
#
# PERMISSION LEVELS:
# ------------------
# - ADMIN: Full workspace admin (can manage all resources)
# - USER: Can create notebooks, clusters, jobs (standard data engineer)
#
# MULTI-WORKSPACE PATTERN:
# ------------------------
# To assign the same user as admin on multiple workspaces:
# 1. Use this module once per workspace
# 2. Pass different workspace_id to each instance
# 3. Same user gets admin on all workspaces automatically
#
# Example in root main.tf:
# module "workspace_permissions_dev" {
#   source     = "./modules/databricks_workspace_permissions"
#   workspace_id = module.databricks_workspace_dev.workspace_id
#   admin_user_email = "skyler@entrada.ai"
# }
#
# module "workspace_permissions_prod" {
#   source     = "./modules/databricks_workspace_permissions"
#   workspace_id = module.databricks_workspace_prod.workspace_id
#   admin_user_email = "skyler@entrada.ai"
# }
#
# TROUBLESHOOTING:
# ----------------
# Error: "User not found"
# - Solution: Ensure SCIM has synced the user from Google
# - Check: Databricks UI → Account Console → User Management
#
# Error: "Group not found"
# - Solution: Ensure SCIM has synced the group from Google
# - Check: Databricks UI → Account Console → Groups
#
# Error: "Permission assignment failed"
# - Solution: Verify you're using account-level provider (databricks.mws)
# - Check: User/group actually exists in Databricks
#
# ============================================================================
