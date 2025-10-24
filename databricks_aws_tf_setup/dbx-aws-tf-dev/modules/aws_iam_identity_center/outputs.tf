# ============================================================================
# AWS IAM Identity Center Module Outputs
# ============================================================================

# ============================================================================
# SCIM Configuration Outputs
# ============================================================================

output "scim_token" {
  description = "OAuth token for AWS IAM Identity Center SCIM provisioning (SENSITIVE - handle securely)"
  value       = databricks_oauthtoken.scim.token_value
  sensitive   = true
}

output "scim_endpoint" {
  description = "SCIM endpoint URL for AWS IAM Identity Center configuration"
  value       = "https://accounts.cloud.databricks.com/api/2.0/accounts/scim/v2"
}

# ============================================================================
# Group IDs
# ============================================================================

output "data_engineers_group_id" {
  description = "ID of the data_engineers group"
  value       = databricks_group.data_engineers.id
}

# ============================================================================
# Setup Instructions
# ============================================================================

output "next_steps" {
  description = "Instructions for completing the SCIM setup in AWS IAM Identity Center"
  value       = <<-EOT

    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                    AWS IAM Identity Center SCIM Setup                         ║
    ║                         NEXT STEPS (Manual - 5 minutes)                       ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝

    1. Copy the SCIM token:
       terraform output -raw identity_center_scim_token

    2. Configure SCIM in AWS Console:
       → AWS Console → IAM Identity Center → Applications
       → Select your Databricks application
       → Click "Edit attribute mappings"
       → Click "Enable automatic provisioning"
       → Paste SCIM endpoint: https://accounts.cloud.databricks.com/api/2.0/accounts/scim/v2
       → Paste SCIM token (from step 1)
       → Click "Save configuration"

    3. Enable provisioning operations:
       → Check "Create users"
       → Check "Update users"
       → Check "Deactivate users"
       → Check "Create groups"
       → Check "Update groups"
       → Click "Save"

    4. Test provisioning:
       → In IAM Identity Center, assign a test user to the Databricks application
       → Check Databricks Account Console → User Management
       → Verify user appears within 1-2 minutes

    5. Create and map AWS groups:
       → Create group in AWS IAM Identity Center: data_engineers
       → Assign users to the group in AWS
       → The group will automatically sync to Databricks
       → For admin access, manually add users to the built-in 'admins' group in Databricks

    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                            PROVISIONED GROUPS                                 ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝

    → admins (built-in):     Full workspace and account admin access
    → data_engineers:        Broad sandbox permissions (CREATE_SCHEMA, CREATE_TABLE,
                            USE_CATALOG, SELECT, MODIFY, CREATE_VOLUME, etc.)

    For detailed instructions, see: modules/aws_iam_identity_center/MANUAL_SETUP_GUIDE.md

  EOT
}
