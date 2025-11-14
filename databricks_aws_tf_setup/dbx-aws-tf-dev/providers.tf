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
# This provider uses the account-level service principal credentials during
# initial provisioning. That avoids circular dependencies between the workspace
# creation flow and the credential bootstrap. After Terraform creates the
# dedicated workspace automation principal, you can override these credentials
# (for example via tfvars or environment variables) to operate purely with that
# principal.
# ============================================================================
provider "databricks" {
  alias         = "workspace"
  host          = local.workspace_url
  client_id     = var.dbx_acc_client_id
  client_secret = var.dbx_acc_client_secret
  auth_type     = "oauth-m2m"
}

provider "databricks" {
  alias         = "workspace_admin"
  host          = local.workspace_url
  client_id     = var.dbx_acc_client_id
  client_secret = var.dbx_acc_client_secret
  auth_type     = "oauth-m2m"
}
