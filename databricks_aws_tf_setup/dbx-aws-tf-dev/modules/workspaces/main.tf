# Create Databricks workspace
resource "databricks_mws_workspaces" "dev" {
  provider        = databricks.mws
  account_id      = var.dbx_account_id
  workspace_name  = var.dbx_ws_name
  deployment_name = var.dbx_ws_deployment_name
  aws_region      = var.aws_region

  # Add your credentials, storage, and network configuration here
  credentials_id           = var.dbx_credentials_id
  storage_configuration_id = var.dbx_storage_config_id
  network_id               = var.dbx_network_id

  # Optional: Add custom tags
  # custom_tags = {
  #   Environment = "dev"
  # }
}

# Output the workspace URL for reference
output "databricks_workspace_url" {
  value       = databricks_mws_workspaces.dev.workspace_url
  description = "URL of the Databricks workspace"
}

output "databricks_workspace_id" {
  value       = databricks_mws_workspaces.dev.workspace_id
  description = "ID of the Databricks workspace"
}
