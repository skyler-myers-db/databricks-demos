/**
 * Databricks Service Principal Module
 *
 * Purpose:
 * Creates a service principal for workspace automation and infrastructure management.
 * Service principals are NOT managed by SCIM - they are Terraform-managed resources.
 *
 * Use Cases:
 * - Infrastructure provisioning (Unity Catalog, external locations, etc.)
 * - CI/CD pipelines (automated deployments)
 * - Workspace-level automation (notebooks, jobs, clusters)
 *
 * Key Features:
 * - Account-level service principal creation
 * - OAuth secret generation for authentication
 * - Workspace admin assignment (workspace-level only, not account admin)
 * - Integration with workspace provider for resource management
 *
 * Security:
 * - Secrets stored in Terraform state (use remote backend with encryption)
 * - Least-privilege: Workspace admin only, not account admin
 * - OAuth M2M authentication (more secure than PAT tokens)
 * - Automatic secret rotation capability
 *
 * IMPORTANT DISTINCTION:
 * - Human users: Managed by Google SCIM (source of truth)
 * - Service principals: Managed by Terraform (automation accounts)
 *
 * Databricks Documentation:
 * https://docs.databricks.com/dev-tools/auth/oauth-m2m.html
 *
 * Cost: $0/month (service principals are free)
 */

# ============================================================================
# SERVICE PRINCIPAL FOR WORKSPACE INFRASTRUCTURE MANAGEMENT
# ============================================================================
# Creates a service principal that will be used for Terraform workspace
# resource provisioning (external locations, catalogs, etc.)

resource "databricks_service_principal" "workspace_terraform" {
  provider     = databricks
  display_name = var.service_principal_name
  active       = true

  # Disable Databricks-managed secrets (we'll create our own OAuth secret)
  # This prevents conflicts with OAuth secret management
  disable_as_user_deletion = false
}

# ============================================================================
# OAUTH SECRET FOR SERVICE PRINCIPAL AUTHENTICATION
# ============================================================================
# Creates OAuth M2M credentials for the service principal
# More secure than Personal Access Tokens (PATs)

resource "databricks_service_principal_secret" "workspace_terraform" {
  provider             = databricks
  service_principal_id = databricks_service_principal.workspace_terraform.id
}

# ============================================================================
# WORKSPACE ADMIN ASSIGNMENT
# ============================================================================
# Assigns the service principal as a workspace admin
# This allows it to manage workspace-level resources (catalogs, external locations, etc.)
# Does NOT grant account-level admin (maintains least-privilege principle)

resource "databricks_mws_permission_assignment" "workspace_admin" {
  provider     = databricks
  workspace_id = var.workspace_id
  principal_id = databricks_service_principal.workspace_terraform.id
  permissions  = ["ADMIN"]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "service_principal_id" {
  description = "Application ID (client ID) of the service principal"
  value       = databricks_service_principal.workspace_terraform.application_id
}

output "service_principal_uuid" {
  description = "UUID of the service principal (for permission assignments)"
  value       = databricks_service_principal.workspace_terraform.id
}

output "oauth_client_id" {
  description = "OAuth client ID for workspace provider authentication (use service principal application ID)"
  value       = databricks_service_principal.workspace_terraform.application_id
}

output "oauth_client_secret" {
  description = "OAuth client secret for workspace provider authentication (SENSITIVE)"
  value       = databricks_service_principal_secret.workspace_terraform.secret
  sensitive   = true
}

output "workspace_url" {
  description = "Workspace URL for the workspace provider configuration"
  value       = var.workspace_url
}

# Configuration for workspace provider
output "workspace_provider_config" {
  description = "Configuration block for Databricks workspace provider"
  value = {
    host          = var.workspace_url
    client_id     = databricks_service_principal.workspace_terraform.application_id
    client_secret = databricks_service_principal_secret.workspace_terraform.secret
    auth_type     = "oauth-m2m"
  }
  sensitive = true
}

# ============================================================================
# USAGE EXAMPLE OUTPUT
# ============================================================================
output "workspace_provider_example" {
  description = "Example Terraform workspace provider configuration"
  value       = <<-EOT
    # Add this to your providers.tf for workspace-level resource management:

    provider "databricks" {
      alias         = "workspace"
      host          = "${var.workspace_url}"
      client_id     = "${databricks_service_principal.workspace_terraform.application_id}"
      client_secret = "${databricks_service_principal_secret.workspace_terraform.secret}"
      auth_type     = "oauth-m2m"
    }

    # Now you can create workspace resources:
    resource "databricks_catalog" "main" {
      provider = databricks.workspace
      name     = "main"
      # ... rest of configuration
    }
  EOT
  sensitive   = true
}

# ============================================================================
# SECURITY AND BEST PRACTICES NOTES
# ============================================================================
#
# CREDENTIAL STORAGE:
# -------------------
# OAuth secrets are stored in Terraform state. Best practices:
# 1. Use remote backend (S3) with encryption
# 2. Enable state locking (DynamoDB)
# 3. Restrict state file access (IAM policies)
# 4. Consider using terraform_remote_state data source for separation
#
# ROTATION STRATEGY:
# ------------------
# To rotate OAuth secret:
# 1. Create new databricks_service_principal_secret resource
# 2. Update workspace provider to use new credentials
# 3. Verify all automation works with new credentials
# 4. Remove old databricks_service_principal_secret resource
# 5. Run terraform apply
#
# LEAST PRIVILEGE:
# ----------------
# This service principal is:
# - Workspace admin (can manage workspace resources)
# - NOT account admin (cannot create new workspaces or modify account)
# - Scoped to single workspace (isolation)
#
# ALTERNATIVE: Multiple Service Principals
# -----------------------------------------
# For larger organizations, consider:
# - infra-admin: Manages external locations, catalogs
# - data-admin: Manages schemas, tables, grants
# - automation: Runs jobs, creates clusters
#
# MONITORING:
# -----------
# - Service principal actions logged in audit logs
# - Monitor for unusual activity (excessive permissions changes)
# - Set up alerts for failed authentication attempts
# - Regular review of service principal permissions
#
# ============================================================================
