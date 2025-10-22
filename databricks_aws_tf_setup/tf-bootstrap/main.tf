module "network" {
  source                = "./modules/network"
  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  endpoint_subnet_cidrs = var.endpoint_subnet_cidrs
  tags                  = var.tags
}

module "storage" {
  source           = "./modules/storage"
  root_bucket_name = var.root_bucket_name
  log_bucket_name  = var.log_bucket_name
  kms_key_alias    = var.kms_key_alias
  vpc_id           = module.network.vpc_id
  vpce_ids         = module.vpc_endpoints.s3_gw_vpce_ids # gateway endpoint IDs for policy conditions (if any)
  tags             = var.tags
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  s3_root_arn  = module.storage.root_bucket_arn
  s3_logs_arn  = module.storage.log_bucket_arn
  kms_key_arn  = module.storage.kms_key_arn
  tags         = var.tags
}

module "vpc_endpoints" {
  source                 = "./modules/vpc_endpoints"
  vpc_id                 = module.network.vpc_id
  subnet_ids             = module.network.endpoint_subnet_ids != [] ? module.network.endpoint_subnet_ids : module.network.private_subnet_ids
  sg_id                  = module.network.vpce_sg_id
  route_table_ids        = module.network.private_route_table_ids
  aws_region             = var.aws_region
  relay_service_name     = var.databricks_relay_service_name
  workspace_service_name = var.databricks_workspace_service_name
  enable_backend_pl      = var.enable_privatelink_backend
  tags                   = var.tags
}

module "databricks_account" {
  source = "./modules/databricks_account"
  providers = {
    databricks.mws = databricks.mws
    databricks     = databricks.ws
  }
  project_name                = var.project_name
  aws_region                  = var.aws_region
  workspace_name              = var.workspace_name
  databricks_account_id       = var.databricks_account_id
  vpc_id                      = module.network.vpc_id
  private_subnet_ids          = module.network.private_subnet_ids
  workspace_sg_id             = module.network.workspace_sg_id
  route_table_ids             = module.network.private_route_table_ids
  credentials_role_arn        = module.iam.databricks_cross_account_role_arn
  storage_config_bucket       = module.storage.root_bucket
  log_delivery_bucket         = module.storage.log_bucket
  enable_privatelink_backend  = var.enable_privatelink_backend
  relay_vpce_id               = module.vpc_endpoints.relay_vpce_id
  restapi_vpce_id             = module.vpc_endpoints.restapi_vpce_id
  enable_privatelink_frontend = var.enable_privatelink_frontend
  create_workspace_principal  = var.enable_workspace_resources
  tags                        = var.tags
}

module "uc" {
  count  = var.enable_workspace_resources ? 1 : 0
  source = "./modules/uc"
  providers = {
    databricks.ws  = databricks.ws
    databricks.mws = databricks.mws
  }
  region                     = var.aws_region
  metastore_storage_root     = "s3://${module.storage.root_bucket}/metastore"
  cross_account_role_arn     = module.iam.databricks_cross_account_role_arn
  workspace_id               = module.databricks_account.workspace_id
  enable_system_tables       = var.enable_system_tables
  federation_example_enabled = var.federation_example_enabled
  federation_conn = {
    type     = var.federation_conn_type
    host     = var.federation_conn_host
    port     = var.federation_conn_port
    user     = var.federation_conn_user
    password = var.federation_conn_password
    database = var.federation_database
  }
  tags = var.tags
}

module "workspace" {
  count       = var.enable_workspace_resources ? 1 : 0
  source      = "./modules/workspace"
  providers   = { databricks = databricks.ws }
  admin_group = var.workspace_admin_group
  tags        = var.tags
}

module "log_delivery" {
  source                = "./modules/log_delivery"
  providers             = { databricks.mws = databricks.mws }
  bucket                = module.storage.log_bucket
  creds_id              = module.databricks_account.credentials_id
  storage_config_id     = module.databricks_account.storage_config_id
  databricks_account_id = var.databricks_account_id
}

module "hardening_flow_logs" {
  source = "./modules/hardening/flow_logs"
  count  = var.enable_flow_logs ? 1 : 0
  vpc_id = module.network.vpc_id
  tags   = var.tags
}

module "hardening_s3_account_block" {
  source = "./modules/hardening/s3_account_block"
  count  = var.enable_s3_account_block ? 1 : 0
}

module "dns_privatelink" {
  source      = "./modules/dns_privatelink"
  count       = var.enable_privatelink_frontend ? 1 : 0
  vpc_id      = module.network.vpc_id
  domain_name = var.pl_phz_domain
  # Docs require A record mapping <deployment>.cloud.databricks.com to your VPCE private IP(s).
  workspace_deployment_fqdn = var.workspace_url      # e.g. oregon.cloud.databricks.com
  workspace_dp_cname        = var.workspace_dp_cname # dbc-dp-<workspace-id>.cloud.databricks.com
  vpce_ips                  = var.frontend_vpce_ips
}
