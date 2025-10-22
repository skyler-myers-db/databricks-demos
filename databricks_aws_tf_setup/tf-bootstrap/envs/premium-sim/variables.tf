# All variables are forwarded to root module
variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "databricks_account_id" {
  type = string
}

variable "databricks_client_id" {
  type = string
}

variable "databricks_client_secret" {
  type      = string
  sensitive = true
}

variable "workspace_name" {
  type = string
}

variable "workspace_admin_group" {
  type    = string
  default = "admins"
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "endpoint_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "root_bucket_name" {
  type = string
}

variable "log_bucket_name" {
  type = string
}

variable "kms_key_alias" {
  type    = string
  default = "alias/databricks-root"
}

variable "pl_phz_domain" {
  type    = string
  default = ""
}

variable "workspace_deployment_name" {
  type    = string
  default = ""
}

variable "workspace_dp_cname" {
  type    = string
  default = ""
}

variable "workspace_url" {
  type    = string
  default = ""
}

variable "frontend_vpce_ips" {
  type    = list(string)
  default = []
}

variable "federation_example_enabled" {
  type    = bool
  default = false
}

variable "federation_conn_type" {
  type    = string
  default = "POSTGRESQL"
}

variable "federation_conn_host" {
  type    = string
  default = ""
}

variable "federation_conn_port" {
  type    = number
  default = 5432
}

variable "federation_conn_user" {
  type    = string
  default = ""
}

variable "federation_conn_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "federation_database" {
  type    = string
  default = ""
}

variable "enable_workspace_resources" {
  type    = bool
  default = false
}
