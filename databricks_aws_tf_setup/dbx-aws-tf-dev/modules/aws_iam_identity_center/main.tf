/**
 * AWS IAM Identity Center + Databricks SCIM Integration
 *
 * This module configures Databricks-side resources for SCIM provisioning from AWS IAM Identity Center.
 * It uses your existing Databricks account admin service principal for SCIM authentication.
 *
 * PREREQUISITES (Manual Setup Required - See MANUAL_SETUP_GUIDE.md):
 * 1. AWS IAM Identity Center enabled in your AWS account
 * 2. G-Suite SAML 2.0 app configured for AWS IAM Identity Center
 * 3. AWS IAM Identity Center configured with G-Suite as external IdP
 * 4. Databricks SAML application created in AWS IAM Identity Center
 *
 * WHAT THIS MODULE AUTOMATES:
 * - OAuth token generation using existing service principal (1-year lifetime, rotatable)
 * - Group creation and permission management in Databricks
 * - Unity Catalog grants for groups
 *
 * GROUPS CREATED:
 * - data_engineers: Broad sandbox permissions for experimentation
 * - Built-in 'admins' group used for admin access (not created here)
 */

# ============================================================================
# OAuth Token for SCIM API Access (Using Existing Service Principal)
# ============================================================================
# Generate a long-lived OAuth token for your existing account admin service principal
# This token will be used by AWS IAM Identity Center to authenticate SCIM requests

resource "databricks_oauthtoken" "scim" {
  provider         = databricks.mws
  application_id   = var.existing_service_principal_client_id
  lifetime_seconds = var.oauth_token_lifetime_seconds
  comment          = "SCIM provisioning token for AWS IAM Identity Center - managed by Terraform"
}

# ============================================================================
# Databricks Groups (Mapped from AWS IAM Identity Center)
# ============================================================================
# Create Databricks groups that will be synchronized from AWS IAM Identity Center
# Users assigned to these groups in AWS will automatically be provisioned in Databricks

# Data Engineers - Broad sandbox access for development and experimentation
resource "databricks_group" "data_engineers" {
  provider     = databricks.mws
  display_name = var.group_data_engineers_name
  force        = false
}

# ============================================================================
# Unity Catalog Permissions
# ============================================================================
# Grant broad Unity Catalog permissions for sandbox environment
# Data engineers get extensive permissions for experimentation

# Data Engineers: Full sandbox access (create, read, write, modify)
resource "databricks_grants" "data_engineers_catalog" {
  provider = databricks.mws
  catalog  = var.unity_catalog_name

  grant {
    principal = databricks_group.data_engineers.display_name
    privileges = [
      "USE_CATALOG",
      "USE_SCHEMA",
      "CREATE_SCHEMA",
      "CREATE_TABLE",
      "CREATE_FUNCTION",
      "CREATE_VOLUME",
      "SELECT",
      "MODIFY",
      "READ_VOLUME",
      "WRITE_VOLUME"
    ]
  }
}
