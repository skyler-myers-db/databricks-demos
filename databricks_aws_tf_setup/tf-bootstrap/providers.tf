# Root providers are intentionally not configured; each env configures providers
# to avoid accidental cross-account/region mistakes.

provider "aws" {
  region = var.aws_region
}

# Account level Databricks provider (Accounts Console APIs)
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
  auth_type     = "oauth-m2m"
}

# Workspace level Databricks provider (set workspace_url before enabling workspace resources)
provider "databricks" {
  alias         = "ws"
  host          = var.enable_workspace_resources && var.workspace_url != "" ? var.workspace_url : "https://placeholder.invalid"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
  auth_type     = "oauth-m2m"
}
