provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.aws_tags
  }
}

provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.dbx_acc_id
  client_id     = var.dbx_acc_client_id
  client_secret = var.dbx_acc_client_secret
  auth_type     = "oauth-m2m"
}
