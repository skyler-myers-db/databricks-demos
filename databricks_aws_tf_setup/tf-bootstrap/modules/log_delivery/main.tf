terraform {
  required_providers {
    databricks = {
      source               = "databricks/databricks"
      configuration_aliases = [databricks.mws]
    }
  }
}

# Configure MWS log delivery for audit/usage/rsyslog (account-level)
resource "databricks_mws_log_delivery" "audit" {
  provider                = databricks.mws
  account_id               = var.databricks_account_id
  config_name              = "audit-logs"
  log_type                 = "AUDIT_LOGS"
  output_format            = "JSON"
  delivery_path_prefix     = "audit"
  credentials_id           = var.creds_id
  storage_configuration_id = var.storage_config_id
}

resource "databricks_mws_log_delivery" "usage" {
  provider                = databricks.mws
  account_id               = var.databricks_account_id
  config_name              = "usage-logs"
  log_type                 = "BILLABLE_USAGE"
  output_format            = "CSV"
  delivery_path_prefix     = "usage"
  credentials_id           = var.creds_id
  storage_configuration_id = var.storage_config_id
}
