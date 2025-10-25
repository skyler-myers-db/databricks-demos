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
# WORKSPACE PROVIDER - Uncomment after service principal is created
# ============================================================================
# This provider uses the service principal created by Terraform to manage
# workspace-level resources (catalogs, external locations, schemas, etc.)
#
# SETUP STEPS:
# 1. Run: terraform apply (creates service principal with OAuth credentials)
# 2. Get credentials: terraform output workspace_service_principal_client_secret
# 3. Uncomment the provider below and fill in the credentials
# 4. Run: terraform apply again (now you can manage workspace resources)
#
# ALTERNATIVE: Use terraform_remote_state to reference outputs from this root module
# ============================================================================

# provider "databricks" {
#   alias         = "workspace"
#   host          = module.databricks_workspace.workspace_url
#   client_id     = module.workspace_service_principal.oauth_client_id
#   client_secret = module.workspace_service_principal.oauth_client_secret
#   auth_type     = "oauth-m2m"
# }

# Example usage of workspace provider:
# resource "databricks_catalog" "main" {
#   provider = databricks.workspace
#   name     = "main"
#   comment  = "Main production catalog"
#   properties = {
#     purpose = "production"
#   }
# }
