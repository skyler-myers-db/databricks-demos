terraform {
  backend "local" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.17.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.94.0"
    }
  }
}

module "stack" {
  source       = "../.."
  project_name = var.project_name
  aws_region   = var.aws_region
  tags         = var.tags

  databricks_account_id    = var.databricks_account_id
  databricks_client_id     = var.databricks_client_id
  databricks_client_secret = var.databricks_client_secret

  workspace_name        = var.workspace_name
  workspace_admin_group = var.workspace_admin_group

  vpc_cidr              = var.vpc_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  endpoint_subnet_cidrs = var.endpoint_subnet_cidrs

  root_bucket_name = var.root_bucket_name
  log_bucket_name  = var.log_bucket_name
  kms_key_alias    = var.kms_key_alias

  workspace_url              = var.workspace_url
  enable_workspace_resources = var.enable_workspace_resources

  enable_privatelink_backend  = false # ENTERPRISE-ONLY
  enable_privatelink_frontend = false # ENTERPRISE-ONLY
  enable_system_tables        = true
  enable_flow_logs            = true
  enable_s3_account_block     = true

  federation_example_enabled = false
}

# Provider configuration
provider "aws" { region = var.aws_region }
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
  auth_type     = "oauth-m2m"
}
