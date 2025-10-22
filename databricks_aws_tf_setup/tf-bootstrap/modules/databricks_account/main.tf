terraform {
  required_providers {
    databricks = {
      source                = "databricks/databricks"
      configuration_aliases = [databricks.mws, databricks]
    }
  }
}

# This module assumes provider databricks.mws is set

# Credentials + storage
resource "databricks_mws_credentials" "creds" {
  provider         = databricks.mws
  role_arn         = var.credentials_role_arn
  credentials_name = "${var.project_name}-creds"
}

resource "databricks_mws_storage_configurations" "storage" {
  account_id                 = var.databricks_account_id
  provider                   = databricks.mws
  storage_configuration_name = "${var.project_name}-storage"
  bucket_name                = var.storage_config_bucket
}

# Register backend VPCEs (if enabled)
resource "databricks_mws_vpc_endpoint" "relay" {
  provider            = databricks.mws
  count               = var.enable_privatelink_backend && var.relay_vpce_id != null ? 1 : 0
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = var.relay_vpce_id
  vpc_endpoint_name   = "${var.project_name}-relay"
  region              = var.aws_region
}

resource "databricks_mws_vpc_endpoint" "restapi" {
  provider            = databricks.mws
  count               = var.enable_privatelink_backend && var.restapi_vpce_id != null ? 1 : 0
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = var.restapi_vpce_id
  vpc_endpoint_name   = "${var.project_name}-restapi"
  region              = var.aws_region
}

# Network configuration: customer managed VPC + (optional) back-end PL endpoints
resource "databricks_mws_networks" "net" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${var.project_name}-network"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.workspace_sg_id]
  # For PrivateLink back-end
  dynamic "vpc_endpoints" {
    for_each = var.enable_privatelink_backend ? [1] : []
    content {
      # In latest provider, these attributes map to SCC relay & workspace REST API registrations.
      dataplane_relay = [for r in databricks_mws_vpc_endpoint.relay : r.vpc_endpoint_id]
      rest_api        = [for r in databricks_mws_vpc_endpoint.restapi : r.vpc_endpoint_id]
    }
  }
}

# Private Access Settings for front-end PL (PAS)
resource "databricks_mws_private_access_settings" "pas" {
  provider                     = databricks.mws
  count                        = var.enable_privatelink_frontend ? 1 : 0
  private_access_settings_name = "${var.project_name}-pas"
  region                       = var.aws_region
  public_access_enabled        = false
  private_access_level         = "ENDPOINT" # or "ACCOUNT"
}

# Workspace
resource "databricks_mws_workspaces" "ws" {
  provider                 = databricks.mws
  account_id               = var.databricks_account_id
  workspace_name           = var.workspace_name
  aws_region               = var.aws_region
  credentials_id           = databricks_mws_credentials.creds.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.storage.storage_configuration_id
  network_id               = databricks_mws_networks.net.network_id
  # ENTERPRISE-ONLY
  private_access_settings_id = try(databricks_mws_private_access_settings.pas[0].private_access_settings_id, null)
  custom_tags                = var.tags
}

resource "databricks_service_principal" "cicd" {
  count        = var.create_workspace_principal ? 1 : 0
  display_name = "dbx-tf-svp"
  depends_on   = [databricks_mws_workspaces.ws]
}

resource "databricks_service_principal_secret" "cicd" {
  count                = var.create_workspace_principal ? 1 : 0
  service_principal_id = databricks_service_principal.cicd[0].id
  depends_on           = [databricks_mws_workspaces.ws]
  # outputs: client_id, secret (sensitive)
}

output "workspace_id" { value = databricks_mws_workspaces.ws.workspace_id }
output "workspace_url" { value = databricks_mws_workspaces.ws.workspace_url }
output "credentials_id" { value = databricks_mws_credentials.creds.credentials_id }
output "storage_config_id" { value = databricks_mws_storage_configurations.storage.storage_configuration_id }
output "svp_secret" { value = try(databricks_service_principal_secret.cicd[0].secret, null) }
