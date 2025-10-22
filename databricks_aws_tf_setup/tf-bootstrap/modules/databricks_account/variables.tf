variable "project_name"                 { type = string }
variable "aws_region"                   { type = string }
variable "workspace_name"               { type = string }
variable "vpc_id"                       { type = string }
variable "private_subnet_ids"           { type = list(string) }
variable "workspace_sg_id"              { type = string }
variable "route_table_ids"              { type = list(string) }
variable "credentials_role_arn"         { type = string }
variable "storage_config_bucket"        { type = string }
variable "log_delivery_bucket"          { type = string }
variable "enable_privatelink_backend"   { type = bool }
variable "relay_vpce_id"   { type = string }
variable "restapi_vpce_id" { type = string }
variable "enable_privatelink_frontend"  { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "databricks_account_id" { type = string }
variable "create_workspace_principal" {
  type    = bool
  default = false
}
