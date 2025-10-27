# Default provider - uses root account credentials (for Organizations management)
provider "aws" {
  alias  = "root"
  region = var.aws_region

  default_tags {
    tags = var.aws_tags
  }
}

# Provider for the newly created dev account
# Assumes role from root account into dev account
provider "aws" {
  alias  = "dev"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${module.aws_account.account_id}:role/${var.aws_acc_switch_role}"
  }

  default_tags {
    tags = var.aws_tags
  }
}

provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.dbx_account_id
  client_id     = var.dbx_acc_client_id
  client_secret = var.dbx_acc_client_secret
  auth_type     = "oauth-m2m"
}

# ============================================================================
# WORKSPACE PROVIDER - Uses Service Principal OAuth Credentials
# ============================================================================
# This provider uses the service principal created by Terraform to manage
# workspace-level resources (cluster policies, grants, catalogs, etc.)
#
# SINGLE-RUN DEPLOYMENT:
# The provider references outputs from the workspace_service_principal module.
# Terraform will automatically create the service principal first, then use
# its credentials for workspace-level resources via proper dependency chains.
#
# The workspace provider is ALWAYS enabled. Resources that depend on it
# (cluster_policies, catalog_grants) have explicit depends_on to ensure
# the service principal exists before the provider is used.
# ============================================================================

provider "databricks" {
  alias         = "workspace"
  host          = module.databricks_workspace.workspace_url
  client_id     = module.workspace_service_principal.oauth_client_id
  client_secret = module.workspace_service_principal.oauth_client_secret
  auth_type     = "oauth-m2m"
}

provider "databricks" {
  alias         = "workspace_admin"
  host          = module.databricks_workspace.workspace_url
  client_id     = var.dbx_acc_client_id
  client_secret = var.dbx_acc_client_secret
  auth_type     = "oauth-m2m"
}
