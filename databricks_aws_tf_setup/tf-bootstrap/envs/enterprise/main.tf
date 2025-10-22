terraform {
  backend "local" {}
}

module "stack" {
  source = "../.."
  project_name  = var.project_name
  aws_region    = var.aws_region
  tags          = var.tags

  databricks_account_id    = var.databricks_account_id
  databricks_client_id     = var.databricks_client_id
  databricks_client_secret = var.databricks_client_secret

  workspace_name         = var.workspace_name
  workspace_admin_group  = var.workspace_admin_group

  vpc_cidr               = var.vpc_cidr
  private_subnet_cidrs   = var.private_subnet_cidrs
  public_subnet_cidrs    = var.public_subnet_cidrs
  endpoint_subnet_cidrs  = var.endpoint_subnet_cidrs

  root_bucket_name       = var.root_bucket_name
  log_bucket_name        = var.log_bucket_name
  kms_key_alias          = var.kms_key_alias

  enable_privatelink_backend  = true
  enable_privatelink_frontend = true
  enable_system_tables        = true
  enable_flow_logs            = true
  enable_s3_account_block     = true

  pl_phz_domain              = var.pl_phz_domain
  workspace_deployment_name  = var.workspace_deployment_name
  workspace_dp_cname         = var.workspace_dp_cname
  workspace_url              = var.workspace_url
  frontend_vpce_ips          = var.frontend_vpce_ips

  federation_example_enabled = var.federation_example_enabled
  federation_conn_type       = var.federation_conn_type
  federation_conn_host       = var.federation_conn_host
  federation_conn_port       = var.federation_conn_port
  federation_conn_user       = var.federation_conn_user
  federation_conn_password   = var.federation_conn_password
  federation_database        = var.federation_database
}

# Provider configuration inheritance
provider "aws" { region = var.aws_region }
provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
  client_id  = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
